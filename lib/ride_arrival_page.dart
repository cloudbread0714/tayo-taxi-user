import 'package:flutter/material.dart';
import 'destination_input_page.dart';
import 'package:auto_size_text/auto_size_text.dart';

class ArrivedDestinationPage extends StatelessWidget {
  const ArrivedDestinationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              const Spacer(),

              AutoSizeText(
                '목적지에 도착했습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.078,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                maxLines: 1,
                minFontSize: 12,
              ),
              SizedBox(height: screenHeight * 0.020),

              AutoSizeText(
                '기사님에게 결제를 하십시오',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.061,
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                ),
                maxLines: 1,
                minFontSize: 12,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // LocationPage로 이동
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LocationPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade200,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: TextStyle(fontSize: screenWidth * 0.056, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
