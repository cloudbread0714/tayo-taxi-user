import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'pickup_location_page.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchNearbyPlaces();
  }

  Future<void> _fetchNearbyPlaces() async {
    final apiKey = dotenv.env['TMAP_API_KEY'];
    debugPrint('🔍 API 키 확인: $apiKey');
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

        debugPrint('🔎 요청 URL: $url');
        debugPrint('🔎 API 응답: ${response.body}');


        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final pois = data['searchPoiInfo']?['pois']?['poi'] ?? [];

          for (final poi in pois) {
            final name = poi['name'] ?? '';
            if (name.contains('주차장')) continue;

            final latVal = double.tryParse(poi['noorLat'] ?? '');
            final lonVal = double.tryParse(poi['noorLon'] ?? '');

            if (latVal != null && lonVal != null) {
              results.add({
                'name': name,
                'lat': latVal,
                'lon': lonVal,
                'address': '${poi['upperAddrName']} ${poi['middleAddrName']}',
              });
              break; // ✅ 다음 keyword로 넘어감
            }
          }
        } else {
          debugPrint('❌ TMAP 응답 오류: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('❌ TMAP 요청 실패: $e');
        _showSnackbar('🚨 장소 요청 중 오류가 발생했습니다!');
      }
    }

    setState(() {
      nearbyPlaces = results.take(5).toList();
      isLoading = false;
    });
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("픽업 장소 선택")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : nearbyPlaces.isEmpty
          ? const Center(child: Text("❌ 근처 추천 장소를 찾을 수 없습니다."))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '📍 픽업 위치를 선택해주세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: nearbyPlaces.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = nearbyPlaces[index];
                return ListTile(
                  title: Text(place['name']),
                  subtitle: Text(place['address']),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PickupLocationPage(
                          suggestedPlaceName: widget.suggestedPlaceName,
                          currentLocation: widget.currentLocation,
                          destinationLocation: widget.destinationLocation,
                          pickupLatLng: LatLng(place['lat'], place['lon']),
                          pickupName: place['name'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}