// bookmark_places_page.dart
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

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _bookmarksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookmarks');
    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
    });
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

  Future<void> _addBookmark(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['placeId'] as String;
    final latLng = await _getLatLng(placeId);
    await _bookmarksRef.add({
      'placeId': placeId,
      'placeName': suggestion['placeName'],
      'address': suggestion['address'],
      'lat': latLng.lat,
      'lng': latLng.lng,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _searchController.clear();
    setState(() => suggestions = []);
  }

  Future<void> _deleteBookmark(String docId) =>
      _bookmarksRef.doc(docId).delete();

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('즐겨찾기'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1) 검색창
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                hintText: '장소 검색',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2) 남은 영역을 통째로 차지하게 한 뒤, 그 위에 자동완성 리스트를 오버레이로 띄웁니다.
            Expanded(
              child: Stack(
                children: [
                  // 2-1) 아래에 깔려 있는 즐겨찾기 목록 (스트림)
                  StreamBuilder<QuerySnapshot>(
                    stream: _bookmarksRef
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text('등록된 즐겨찾기가 없습니다.'));
                      }
                      return ListView(
                        padding: const EdgeInsets.only(top: 0),
                        children: docs.map((doc) {
                          final data = doc.data()! as Map<String, dynamic>;
                          return Card(
                            color: Colors.green.shade200,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(data['placeName'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              subtitle: Text(data['address'], style: const TextStyle(fontSize: 14)),
                              onTap: () {
                                Navigator.pop(context, {
                                  'placeName': data['placeName'],
                                  'address': data['address'],
                                  'lat': data['lat'],
                                  'lng': data['lng'],
                                });
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.black),
                                onPressed: () => _deleteBookmark(doc.id),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  // 2-2) 자동완성 리스트가 있을 때만 보여줌
                  if (suggestions.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        // 원하는 높이로 고정
                        constraints: BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          // 스크롤 가능하게
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, i) {
                            final s = suggestions[i];
                            return ListTile(
                              title: Text(s['placeName'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              subtitle: Text(s['address'], style: const TextStyle(fontSize: 14)),
                              trailing: ElevatedButton(
                                onPressed: () => _addBookmark(s),
                                child: const Text('추가'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade200,
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
