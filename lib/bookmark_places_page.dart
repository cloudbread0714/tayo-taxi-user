import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text(_home!['address'],
                    style: const TextStyle(fontSize: 14)),
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
            const SizedBox(height: 16),
            // 검색창
            TextField(
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
            const SizedBox(height: 8),
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
                        return const Center(
                            child: Text('등록된 즐겨찾기가 없습니다.'));
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
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  data['address'],
                                  style: const TextStyle(fontSize: 14),
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
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(s['address'],
                                  style: const TextStyle(fontSize: 14)),
                              trailing: ElevatedButton(
                                onPressed: () => _addBookmark(s,
                                    isHome: _isHomeMode),
                                child: const Text('추가'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isHomeMode
                                      ? Colors.blue.shade100
                                      : Colors.green.shade200,
                                  foregroundColor: Colors.black,
                                ),
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
}

class LatLng {
  final double lat, lng;
  LatLng({required this.lat, required this.lng});
}
