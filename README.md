<div align="center">

# 🚕 타요택시 (Tayo Taxi)

**시니어 맞춤형 택시 호출 앱 — 사용자(승객) 앱**

현재 위치 주변 500m 이내 랜드마크를 픽업 장소로 추천해,<br>
주소를 몰라도 쉽게 택시를 부를 수 있도록 만든 Flutter 앱입니다.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![Google Places](https://img.shields.io/badge/Google%20Places-4285F4?style=flat-square&logo=googlemaps&logoColor=white)
![Naver Map](https://img.shields.io/badge/Naver%20Map-03C75A?style=flat-square&logo=naver&logoColor=white)

[기사 앱 저장소 →](https://github.com/cloudbread0714/tayo-taxi-driver)

</div>

---

## 📦 제출 자료

| 항목 | 링크 |
|------|------|
| 🎬 시연 영상 | [YouTube에서 보기](https://www.youtube.com/shorts/5BCnoYH2l_A) |
| 🖼️ 포스터 | [docs/poster.pdf](docs/poster.pdf) |
| 📄 결과보고서 | [docs/final-report.pdf](docs/final-report.pdf) |
| 💻 소스 코드 | [`lib/`](lib) (사용자 앱) · [기사 앱 저장소](https://github.com/cloudbread0714/tayo-taxi-driver) |
| 🛠️ 개발 문서 | [실행 방법](#-실행-방법) · [프로젝트 구조](#-프로젝트-구조) · [플로우 차트](#-플로우-차트) |

---

## 🎬 시연 영상

<p align="center">
  <a href="https://www.youtube.com/shorts/5BCnoYH2l_A">
    <img src="images/demo-thumbnail.jpg" alt="타요택시 시연 영상" width="560"/>
  </a>
  <br>
  <sub>이미지를 누르면 YouTube에서 재생됩니다.</sub>
</p>

## 🖼️ 포스터

<p align="center">
  <a href="docs/poster.pdf">
    <img src="images/poster.png" alt="타요택시 포스터" width="720"/>
  </a>
</p>

---

## ✨ 주요 기능

| 기능 | 설명 |
|------|------|
| 📍 현재 위치 추적 | Geolocator로 현재 위치를 자동으로 가져옵니다. |
| 🏪 랜드마크 픽업 추천 | 500m 이내 약국·편의점·주민센터·학교 정문 등을 리스트로 보여주고 픽업 위치로 선택합니다. |
| 🎙️ 음성 목적지 입력 | 말로 목적지를 입력하면 Google Places로 장소를 찾아줍니다. |
| ⭐ 즐겨찾기 · 이용 내역 | 자주 가는 장소를 저장하고 지난 호출 기록을 확인합니다. |
| 🔐 인증 · 실시간 연동 | Firebase Authentication으로 로그인하고, Firestore로 기사 앱과 호출·운행 상태를 실시간 공유합니다. |

## 🧰 기술 스택

| 구분 | 기술 | 용도 |
|------|------|------|
| 프레임워크 | Flutter (Dart) | 크로스 플랫폼 앱 개발 |
| 백엔드 | Firebase Authentication | 로그인 / 회원가입 |
| | Cloud Firestore | 호출·운행 실시간 데이터 |
| 지도 / 위치 | Google Places API | 목적지 자동완성, 음성 장소 추출 |
| | Tmap API | 500m 이내 랜드마크 픽업 추천 |
| | Naver Map SDK | 픽업 위치 지도 표시 |
| | Geolocator | 현재 위치 조회 |

## 🔀 플로우 차트

<p align="center">
  <img src="images/기능_흐름도.png" alt="기능 흐름도" width="720"/>
</p>

---

## 📁 프로젝트 구조

```
tayo-taxi-user/
├── lib/
│   ├── main.dart                        # 앱 진입점 (dotenv · Firebase · Naver Map 초기화)
│   ├── user_login_page.dart             # 로그인
│   ├── user_signup_page.dart            # 회원가입
│   ├── user_profile_page.dart           # 마이페이지
│   ├── user_info_form.dart              # 내 정보
│   ├── family_info_form.dart            # 보호자 정보
│   ├── destination_input_page.dart      # 목적지 입력 (텍스트 / 음성)
│   ├── pickup_place_list_page.dart      # 500m 이내 랜드마크 리스트
│   ├── select_pickup_location_page.dart # 픽업 위치 지도 선택
│   ├── ride_waiting_page.dart           # 배차 대기
│   ├── ride_arrival_page.dart           # 기사 도착
│   ├── ride_in_progress_page.dart       # 운행 중
│   ├── ride_history_page.dart           # 이용 내역
│   ├── bookmark_places_page.dart        # 즐겨찾기
│   └── services/extract_place.dart      # 음성 입력 → 장소 추출
├── docs/                                # 결과보고서 · 포스터 PDF
├── images/                              # README 이미지
├── firestore.rules                      # Firestore 보안 규칙
└── .env.example                         # 환경 변수 템플릿
```

## 🚀 실행 방법

**요구 사항**: Flutter SDK 3.7 이상, Android Studio 또는 Xcode

```bash
# 1. 저장소 클론
git clone https://github.com/cloudbread0714/tayo-taxi-user.git
cd tayo-taxi-user

# 2. 환경 변수 설정: .env.example을 복사한 뒤 API 키 입력
cp .env.example .env

# 3. 패키지 설치 및 실행
flutter pub get
flutter run
```

| 환경 변수 | 발급처 |
|-----------|--------|
| `GOOGLE_API_KEY` | Google Cloud Console (Places API) |
| `NAVER_CLIENT_ID` | NAVER Cloud Platform (Maps) |
| `TMAP_API_KEY` | SK open API (Tmap) |
| `FIREBASE_API_KEY` | Firebase Console |

> `.env`는 `.gitignore`에 포함되어 있어 저장소에 올라가지 않습니다.

---

## 👥 개발 팀원

| 이름 | 역할 | 주요 담당 업무 |
|------|------|----------------|
| 서정우 | 팀장 · 프론트엔드 | 전체 UI 디자인 및 화면 레이아웃, 즐겨찾기 · 이용 내역, 보고서 작성 |
| 강유진 | 팀원 · 백엔드 | API 및 DB 연동, 로그인 / 회원가입, 랜드마크 기반 위치 탐색, 보고서 작성 |
