import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MyOrderHistoryDetails extends StatelessWidget {
  final Map<String, dynamic> data;

  const MyOrderHistoryDetails({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    // Firestore Timestamp → DateTime
    final acceptedTimestamp = data['acceptedAt'] as Timestamp?;
    final endedTimestamp = data['endedAt'] as Timestamp?;
    final accepted = acceptedTimestamp?.toDate() ?? DateTime.now();
    final ended = endedTimestamp?.toDate() ?? DateTime.now();

    // Format strings
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(accepted);
    final startTimeStr = DateFormat('HH:mm').format(accepted);
    final endTimeStr = DateFormat('HH:mm').format(ended);

    // Other fields
    final pickupPlace = data['pickupPlaceName'] as String? ?? '정보 없음';
    final destinationPlace = data['destinationName'] as String? ?? '정보 없음';
    final driverName = data['driverName'] as String? ?? '미확인';
    final carNumber = data['carNumber'] as String? ?? '미확인';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '상세 내역',
          style: TextStyle(fontSize: screenWidth * 0.061, fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.031),
              Text(
                dateStr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.072,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              SizedBox(height: screenHeight * 0.050),

              // 출발 시간 / 도착 시간 영역
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.025,
                  horizontal: screenWidth * 0.04,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.green, size: 28),
                        SizedBox(width: screenWidth * 0.025),

                        AutoSizeText(
                          '출발 시간:  ',
                          style: TextStyle(
                            fontSize: screenWidth * 0.056,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          minFontSize: 12,
                        ),

                        Expanded(
                          child: AutoSizeText(
                            startTimeStr,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: screenWidth * 0.056),
                            maxLines: 1,
                            minFontSize: 12,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.020),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.green, size: 28),
                        SizedBox(width: screenWidth * 0.025),

                        AutoSizeText(
                          '도착 시간:  ',
                          style: TextStyle(
                            fontSize: screenWidth * 0.056,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          minFontSize: 15,
                        ),

                        Expanded(
                          child: AutoSizeText(
                            endTimeStr,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: screenWidth * 0.056),
                            maxLines: 1,
                            minFontSize: 15,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.030),

              // 출발지 / 도착지 영역
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.025,
                  horizontal: screenWidth * 0.04,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.my_location, color: Colors.green, size: 28),
                        SizedBox(width: screenWidth * 0.025),

                        AutoSizeText(
                          '출발지:  ',
                          style: TextStyle(
                            fontSize: screenWidth * 0.056,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          minFontSize: 12,
                        ),

                        //Spacer(),

                        Expanded(
                          child: AutoSizeText(
                            pickupPlace,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: screenWidth * 0.056),
                            minFontSize: 15,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.025),
                    Row(
                      children: [
                        Icon(Icons.place, color: Colors.green, size: 28),
                        SizedBox(width: screenWidth * 0.025),

                        AutoSizeText(
                          '도착지:  ',
                          style: TextStyle(
                            fontSize: screenWidth * 0.056,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          minFontSize: 12,
                        ),

                        Expanded(
                          child: AutoSizeText(
                            destinationPlace,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: screenWidth * 0.056),
                            maxLines: 2,
                            minFontSize: 15,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.030),

              // 기사님 / 차량 번호 영역
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.025,
                  horizontal: screenWidth * 0.04,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.green, size: 28),
                        SizedBox(width: screenWidth * 0.025),

                        AutoSizeText(
                          '기사님:  ',
                          style: TextStyle(
                            fontSize: screenWidth * 0.056,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          minFontSize: 12,
                        ),

                        Expanded(
                          child: AutoSizeText(
                            driverName,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: screenWidth * 0.056),
                            maxLines: 1,
                            minFontSize: 12,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.025),

                    Row(
                      children: [
                        Icon(Icons.local_taxi, color: Colors.green, size: 28),
                        SizedBox(width: screenWidth * 0.025),

                        // “차량 번호:” 레이블
                        AutoSizeText(
                          '차량 번호:  ',
                          style: TextStyle(
                            fontSize: screenWidth * 0.056,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          minFontSize: 12,
                        ),

                        Expanded(
                          child: AutoSizeText(
                            carNumber,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: screenWidth * 0.056),
                            maxLines: 1,
                            minFontSize: 15,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
