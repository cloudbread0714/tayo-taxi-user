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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('내 정보', style: TextStyle(fontSize: screenWidth * 0.056)),
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
            SizedBox(height: screenHeight * 0.010),
            _buildReadOnlyField(_email),

            SizedBox(height: screenHeight * 0.030),
            _buildLabel('이름'),
            SizedBox(height: screenHeight * 0.010),
            _buildReadOnlyField(_name),

            SizedBox(height: screenHeight * 0.030),
            _buildLabel('전화번호'),
            SizedBox(height: screenHeight * 0.010),
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
                      // 수정 완료 눌렀을 때 DB에 저장
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
                    style: TextStyle(fontSize: screenWidth * 0.044),
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
    final double screenWidth  = MediaQuery.of(context).size.width;
    return Text(text,
      style: TextStyle(fontSize: screenWidth * 0.050, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildReadOnlyField(String text) {
    final double screenWidth  = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: screenWidth * 0.050)),
    );
  }

  Widget _buildPhoneField() {
    final double screenWidth  = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: TextStyle(fontSize: screenWidth * 0.050),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}
