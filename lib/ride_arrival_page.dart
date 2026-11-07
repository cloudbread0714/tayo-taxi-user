import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'destination_input_page.dart';

class ArrivedDestinationPage extends StatefulWidget {
  const ArrivedDestinationPage({Key? key}) : super(key: key);

  @override
  State<ArrivedDestinationPage> createState() => _ArrivedDestinationPageState();
}

class _ArrivedDestinationPageState extends State<ArrivedDestinationPage> {

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
                '목적지에 도착했습니다!',
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
                '기사님에게 결제를 해주세요',
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
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DestinationInputPage()),
                          (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade200,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: TextStyle(fontSize: screenWidth * 0.056,
                        fontWeight: FontWeight.bold),
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
