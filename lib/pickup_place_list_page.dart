import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'select_pickup_location_page.dart';

class PickupListPage extends StatefulWidget {
  final LatLng currentLocation;
  final LatLng destinationLocation;
  final String suggestedPlaceName;

  const PickupListPage({
    super.key,
    required this.currentLocation,
    required this.destinationLocation,
    required this.suggestedPlaceName,
  });

  @override
  State<PickupListPage> createState() => _PickupListPageState();
}

class _PickupListPageState extends State<PickupListPage> {
  List<Map<String, dynamic>> nearbyPlaces = [];
  bool isLoading = true;
  final keywords = ['약국', '편의점', '주민센터', '학교 정문'];
  final Distance distanceCalculator = Distance();
  
  // 튜토리얼 관련 변수들
  final GlobalKey firstSelectButtonKey = GlobalKey();
  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  @override
  void initState() {
    super.initState();
    _fetchNearbyPlaces();
  }

  Future<void> _fetchNearbyPlaces() async {
    final apiKey = dotenv.env['TMAP_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _showSnackbar('❌ TMAP API 키가 설정되지 않았습니다!');
      setState(() => isLoading = false);
      return;
    }

    final lat = widget.currentLocation.latitude;
    final lon = widget.currentLocation.longitude;
    final results = <Map<String, dynamic>>[];

    for (final keyword in keywords) {
      final url = Uri.https(
        'apis.openapi.sk.com',
        '/tmap/pois',
        {
          'version': '1',
          'searchKeyword': keyword,
          'searchType': 'all',
          'page': '1',
          'count': '20',
          'resCoordType': 'WGS84GEO',
          'multiPoint': 'N',
          'searchtypCd': 'A',
          'reqCoordType': 'WGS84GEO',
          'poiGroupYn': 'N',
          'centerLat': lat.toString(),
          'centerLon': lon.toString(),
        },
      );

      try {
        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'appKey': 'm0rGlmgU5ja8VtbQXLREQ1kzRxDSnRcwXEqr86A5',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final pois = data['searchPoiInfo']?['pois']?['poi'] ?? [];

          for (final poi in pois) {
            final name = poi['name'] ?? '';
            if (name.contains('주차장')) continue;

            final latVal = double.tryParse(poi['noorLat'] ?? '');
            final lonVal = double.tryParse(poi['noorLon'] ?? '');

            if (latVal != null && lonVal != null) {
              final meterDistance = distanceCalculator.as(
                LengthUnit.Meter,
                widget.currentLocation,
                LatLng(latVal, lonVal),
              );
              // 500m 초과 시 제외
              if (meterDistance > 500) continue;

              results.add({
                'name': name,
                'lat': latVal,
                'lon': lonVal,
                'address': '${poi['upperAddrName']} ${poi['middleAddrName']}',
              });
              break;
            }
          }
        }
      } catch (e) {
        _showSnackbar('🚨 장소 요청 중 오류가 발생했습니다!');
      }
    }

    setState(() {
      nearbyPlaces = results.take(5).toList();
      isLoading = false;
    });
    
    // 데이터 로드 완료 후 튜토리얼 시작 (로그인 후 1회만)
    if (nearbyPlaces.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowPickupPlaceTutorial(context);
      });
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPickupPlaceTutorial(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    targets.clear();
    targets.addAll([
      TargetFocus(
        identify: "select_button",
        keyTarget: firstSelectButtonKey,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top, // 또는 topCenter
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end, // 오른쪽 정렬
              children: [
                Text(
                  "이 버튼을 눌러 택시를 탑승할 장소를\n선택할 수 있어요",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "버튼을 터치하세요",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenWidth * 0.035,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    ]);

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.8),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {},
      onClickTarget: (target) {
        tutorialCoachMark.next();
        return true;
      },
      onClickOverlay: (target) {
        tutorialCoachMark.next();
        return true;
      },
      onSkip: () {
        return true;
      },
      hideSkip: true,
    );

    tutorialCoachMark.show(context: context);
  }

  Future<void> _checkAndShowPickupPlaceTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown';
    final key = 'has_shown_pickup_place_tutorial_$userId';
    final hasShownTutorial = prefs.getBool(key) ?? false;
    
    if (!hasShownTutorial) {
      await prefs.setBool(key, true);
      _showPickupPlaceTutorial(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('픽업 장소 선택', style: TextStyle(fontSize: screenWidth * 0.056, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : nearbyPlaces.isEmpty
          ? const Center(child: Text("❌ 근처 추천 장소를 찾을 수 없습니다."))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: screenHeight * 0.025),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: AutoSizeText(
                '택시를 탑승할 위치를 선택해주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.056,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                minFontSize: 12,
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.037),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.044),
              itemCount: nearbyPlaces.length,
              separatorBuilder: (_, __) => SizedBox(height: screenHeight * 0.015),
              itemBuilder: (context, index) {
                final place = nearbyPlaces[index];
                return Card(
                  color: Colors.green.shade50,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: AutoSizeText(
                                  place['name'],
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.050,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  minFontSize: 12,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.005),
                              AutoSizeText(
                                place['address'],
                                style: TextStyle(fontSize: screenWidth * 0.044),
                                maxLines: 2,
                                minFontSize: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          key: index == 0 ? firstSelectButtonKey : null, // 첫 번째 아이템에만 GlobalKey 추가
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PickupLocationPage(
                                  suggestedPlaceName: widget.suggestedPlaceName,
                                  currentLocation: widget.currentLocation,
                                  destinationLocation: widget.destinationLocation,
                                  pickupLatLng: LatLng(
                                    place['lat'], place['lon'],
                                  ),
                                  pickupName: place['name'],
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            Colors.green.shade200,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                vertical: 15, horizontal: 24),
                            textStyle: TextStyle(
                                fontSize: screenWidth * 0.044,
                                fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                          ),
                          child:
                          AutoSizeText('선택', style: TextStyle(fontSize: screenWidth * 0.047),
                            maxLines: 1,
                            minFontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
