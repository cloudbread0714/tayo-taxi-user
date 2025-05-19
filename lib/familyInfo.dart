import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyInfoPage extends StatefulWidget {
  const FamilyInfoPage({Key? key}) : super(key: key);

  @override
  State<FamilyInfoPage> createState() => _FamilyInfoPageState();
}

class _FamilyInfoPageState extends State<FamilyInfoPage> {
  // 편집 모드 토글용
  bool _editingRelation = false;
  bool _editingName     = false;
  bool _editingPhone    = false;

  // 컨트롤러
  final _relationCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  // 초기 값 저장용
  String _relation = '';
  String _familyName = '';
  String _familyPhone = '';

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .then((doc) {
      final data = doc.data() ?? {};
      final fam = data['family'] as Map<String, dynamic>? ?? {};
      setState(() {
        _relation     = fam['relation'] ?? '';
        _familyName   = fam['name']     ?? '';
        _familyPhone  = fam['phone']    ?? '';
        _relationCtrl.text = _relation;
        _nameCtrl.text     = _familyName;
        _phoneCtrl.text    = _familyPhone;
      });
    });
  }

  @override
  void dispose() {
    _relationCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('보호자 정보', style: TextStyle(fontSize: 20)),
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
            // 관계
            _buildLabel('관계'),
            const SizedBox(height: 8),
            _buildFieldWithButton(
              isEditing: _editingRelation,
              controller: _relationCtrl,
              readValue: _relation,
              onToggle: () async {
                if (_editingRelation) {
                  final newVal = _relationCtrl.text.trim();
                  await _updateFamilyField(uid, 'relation', newVal);
                  setState(() => _relation = newVal);
                }
                setState(() => _editingRelation = !_editingRelation);
              },
            ),

            const SizedBox(height: 24),
            // 이름
            _buildLabel('이름'),
            const SizedBox(height: 8),
            _buildFieldWithButton(
              isEditing: _editingName,
              controller: _nameCtrl,
              readValue: _familyName,
              onToggle: () async {
                if (_editingName) {
                  final newVal = _nameCtrl.text.trim();
                  await _updateFamilyField(uid, 'name', newVal);
                  setState(() => _familyName = newVal);
                }
                setState(() => _editingName = !_editingName);
              },
            ),

            const SizedBox(height: 24),
            // 전화번호
            _buildLabel('전화번호'),
            const SizedBox(height: 8),
            _buildFieldWithButton(
              isEditing: _editingPhone,
              controller: _phoneCtrl,
              readValue: _familyPhone,
              keyboardType: TextInputType.phone,
              onToggle: () async {
                if (_editingPhone) {
                  final newVal = _phoneCtrl.text.trim();
                  await _updateFamilyField(uid, 'phone', newVal);
                  setState(() => _familyPhone = newVal);
                }
                setState(() => _editingPhone = !_editingPhone);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFieldWithButton({
    required bool isEditing,
    required TextEditingController controller,
    required String readValue,
    required VoidCallback onToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Row(
      children: [
        Expanded(
          child: isEditing
              ? _buildEditableField(controller, keyboardType)
              : _buildReadOnlyField(readValue),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: onToggle,
          icon: Icon(isEditing ? Icons.check : Icons.edit, size: 20),
          label: Text(isEditing ? '완료' : '수정하기',
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
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _buildEditableField(TextEditingController ctrl, TextInputType type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(fontSize: 18),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Future<void> _updateFamilyField(String uid, String key, String value) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'family.$key': value});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('[$key] 정보가 업데이트되었습니다.')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업데이트에 실패했습니다.')),
      );
    }
  }
}
