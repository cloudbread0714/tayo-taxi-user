import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkPlacesPage extends StatefulWidget {
  const BookmarkPlacesPage({Key? key}) : super(key: key);

  @override
  State<BookmarkPlacesPage> createState() => _BookmarkPlacesPageState();
}

class _BookmarkPlacesPageState extends State<BookmarkPlacesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> suggestions = [];
  late final CollectionReference _bookmarksRef;
  final String _apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  bool _isHomeMode = false;
  Map<String, dynamic>? _home;
  
  // 튜토리얼 관련 변수들
  final GlobalKey searchFieldKey = GlobalKey();
  final GlobalKey firstAddButtonKey = GlobalKey();
  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];
  bool _hasShownSearchTutorial = false;
  bool _hasShownAddTutorial = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _bookmarksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookmarks');
    _loadHome();
    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
    });
    
    // 위젯이 완전히 빌드된 후 첫 번째 튜토리얼 시작 (로그인 후 1회만)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowSearchTutorial(context);
    });
  }

  Future<void> _loadHome() async {
    final snap = await _bookmarksRef.where('isHome', isEqualTo: true).limit(1).get();
    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data() as Map<String, dynamic>;
      setState(() {
        _home = {
          'docId': snap.docs.first.id,
          'placeName': data['placeName'],
          'address': data['address'],
        };
      });
    }
  }

  Future<void> _onSearchChanged(String input) async {
    if (input.isEmpty) {
      setState(() => suggestions = []);
      return;
    }
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'key': _apiKey,
        'language': 'ko',
        'components': 'country:kr',
      },
    );
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final preds = data['predictions'] as List;
      setState(() {
        suggestions = preds.map((p) {
          final fmt = p['structured_formatting'];
          return {
            'placeId': p['place_id'],
            'placeName': fmt['main_text'],
            'address': fmt['secondary_text'],
          };
        }).toList();
      });
      
      // 검색 결과가 나타나면 두 번째 튜토리얼 시작 (로그인 후 1회만)
      if (suggestions.isNotEmpty && !_hasShownAddTutorial) {
        _hasShownAddTutorial = true;
        // 약간의 지연시간 추가 (1초)
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _checkAndShowAddButtonTutorial(context);
          }
        });
      }
    }
  }

  Future<LatLng> _getLatLng(String placeId) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry',
        'key': _apiKey,
      },
    );
    final resp = await http.get(url);
    final data = jsonDecode(resp.body);
    final loc = data['result']['geometry']['location'];
    return LatLng(lat: loc['lat'], lng: loc['lng']);
  }

  Future<void> _addBookmark(Map<String, dynamic> suggestion, {bool isHome = false}) async {
    final placeId = suggestion['placeId'] as String;
    final latLng = await _getLatLng(placeId);
    if (isHome) {
      // 기존 home 삭제
      final existing = await _bookmarksRef.where('isHome', isEqualTo: true).get();
      for (var doc in existing.docs) {
        await _bookmarksRef.doc(doc.id).delete();
      }
    }
    await _bookmarksRef.add({
      'placeId': placeId,
      'placeName': suggestion['placeName'],
      'address': suggestion['address'],
      'lat': latLng.lat,
      'lng': latLng.lng,
      'isHome': isHome,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _searchController.clear();
    setState(() {
      suggestions = [];
      _isHomeMode = false;
    });
    if (isHome) _loadHome();
  }

  Future<void> _deleteBookmark(String docId) async =>
      await _bookmarksRef.doc(docId).delete();

  void _showSearchTutorial(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    targets.clear();
    targets.addAll([
      TargetFocus(
        identify: "search_field",
        keyTarget: searchFieldKey,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "자주 가는 장소를 검색해주세요",
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "칸을 터치하세요",
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
      onFinish: () {
        _hasShownSearchTutorial = true;
      },
      onClickTarget: (target) {
        tutorialCoachMark.next();
        return true;
      },
      onClickOverlay: (target) {
        tutorialCoachMark.next();
        return true;
      },
      onSkip: () {
        _hasShownSearchTutorial = true;
        return true;
      },
      hideSkip: true,
    );

    tutorialCoachMark.show(context: context);
  }

  void _showAddButtonTutorial(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    targets.clear();
    targets.addAll([
      TargetFocus(
        identify: "add_button",
        keyTarget: firstAddButtonKey,
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "버튼을 눌러 즐겨찾기 추가를 할 수 있어요",
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "버튼을 터치하세요",
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '즐겨찾기',
          style: TextStyle(
              fontSize: screenWidth * 0.056,
              fontWeight: FontWeight.bold
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Home 설정 영역
            if (_home != null) ...[
              ListTile(
                leading: const Icon(Icons.home, color: Colors.green),
                title: Text(_home!['placeName'],
                    style: TextStyle(
                        fontSize: screenWidth * 0.050, fontWeight: FontWeight.bold)),
                subtitle: Text(_home!['address'],
                    style: TextStyle(fontSize: screenWidth * 0.039)),
                trailing: TextButton(
                  onPressed: () {
                    setState(() {
                      _isHomeMode = true;
                      suggestions = [];
                    });
                  },
                  child: const Text('수정'),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isHomeMode = true;
                    suggestions = [];
                  });
                },
                icon: const Icon(Icons.home),
                label: const Text('집 주소 설정'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
            SizedBox(height: screenHeight * 0.020),
            // 검색창
            TextField(
              key: searchFieldKey,
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  color: _isHomeMode ? Colors.green : Colors.green,
                ),
                hintText: _isHomeMode ? '집 주소 검색' : '장소 검색',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.010),
            Expanded(
              child: Stack(
                children: [
                  // 즐겨찾기 목록 (home 제외)
                  StreamBuilder<QuerySnapshot>(
                    stream: _bookmarksRef
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      final list = docs.where((doc) {
                        final d = doc.data()! as Map<String, dynamic>;
                        return d['isHome'] != true;
                      }).toList();
                      if (list.isEmpty) {
                        return Center(
                            child: AutoSizeText(
                                '등록된 즐겨찾기가 없습니다.',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.050
                              ),
                              maxLines: 1,
                              minFontSize: 12,
                            )
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.only(top: 0),
                        children: list.map((doc) {
                          final data = doc.data()! as Map<String, dynamic>;
                          return Card(
                            color: Colors.green.shade100,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: SizedBox(
                              height: 90,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                title: Text(
                                  data['placeName'],
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.050,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: AutoSizeText(
                                  data['address'],
                                  style: TextStyle(fontSize: screenWidth * 0.039),
                                  maxLines: 1,
                                  minFontSize: 12,
                                ),
                                onTap: () {
                                  Navigator.pop(context, {
                                    'placeName': data['placeName'],
                                    'address': data['address'],
                                    'lat': data['lat'],
                                    'lng': data['lng'],
                                  });
                                },
                                trailing: Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.black),
                                    onPressed: () => _deleteBookmark(doc.id),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  if (suggestions.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, i) {
                            final s = suggestions[i];
                            return ListTile(
                              title: Text(s['placeName'],
                                  style: TextStyle(
                                      fontSize: screenWidth * 0.050,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(s['address'],
                                  style: TextStyle(fontSize: screenWidth * 0.039)),
                              trailing: ElevatedButton(
                                key: i == 0 ? firstAddButtonKey : null, // 첫 번째 아이템에만 GlobalKey 추가
                                onPressed: () => _addBookmark(s,
                                    isHome: _isHomeMode),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isHomeMode
                                      ? Colors.blue.shade100
                                      : Colors.green.shade200,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('추가'),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowSearchTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown';
    final key = 'has_shown_bookmark_search_tutorial_$userId';
    final hasShownTutorial = prefs.getBool(key) ?? false;
    
    if (!hasShownTutorial) {
      await prefs.setBool(key, true);
      _showSearchTutorial(context);
    }
  }

  Future<void> _checkAndShowAddButtonTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown';
    final key = 'has_shown_bookmark_add_tutorial_$userId';
    final hasShownTutorial = prefs.getBool(key) ?? false;
    
    if (!hasShownTutorial) {
      await prefs.setBool(key, true);
      _showAddButtonTutorial(context);
    }
  }
}

class LatLng {
  final double lat, lng;
  LatLng({required this.lat, required this.lng});
}
