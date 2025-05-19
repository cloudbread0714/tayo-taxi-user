import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyInfoPage extends StatefulWidget {
  const MyInfoPage({Key? key}) : super(key: key);

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  bool _isEditingPhone = false;
  final _phoneController = TextEditingController();

  String _email = '';
  String _name = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    _email = user.email!;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((doc) {
      final data = doc.data() ?? {};
      setState(() {
        _name = data['name'] ?? '';
        _phone = data['phone'] ?? '';
        _phoneController.text = _phone;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보', style: TextStyle(fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('아이디'),
            const SizedBox(height: 8),
            _buildReadOnlyField(_email),

            const SizedBox(height: 24),
            _buildLabel('이름'),
            const SizedBox(height: 8),
            _buildReadOnlyField(_name),

            const SizedBox(height: 24),
            _buildLabel('전화번호'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _isEditingPhone
                      ? _buildPhoneField()
                      : _buildReadOnlyField(_phone),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (_isEditingPhone) {
                      // 방금 수정 완료 눌렀을 때 DB에 저장
                      final newPhone = _phoneController.text.trim();
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .update({'phone': newPhone});
                        setState(() {
                          _phone = newPhone;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('전화번호가 업데이트되었습니다.')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('업데이트에 실패했습니다.')),
                        );
                      }
                    }
                    setState(() {
                      _isEditingPhone = !_isEditingPhone;
                    });
                  },
                  icon: Icon(_isEditingPhone ? Icons.check : Icons.edit, size: 20),
                  label: Text(_isEditingPhone ? '완료' : '수정하기',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 18),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}
