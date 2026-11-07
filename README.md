# 타요택시 (Tayo Taxi)

시니어 맞춤형 택시 호출 앱 · Flutter · Firebase

기사 앱: [tayo-taxi-driver](https://github.com/cloudbread0714/tayo-taxi-driver)

---

## 시연 영상

<p align="center">
  <a href="https://www.youtube.com/shorts/5BCnoYH2l_A">
    <img src="images/demo-thumbnail.jpg" alt="타요택시 시연 영상" width="560"/>
  </a>
</p>

<p align="center">
  <a href="https://www.youtube.com/shorts/5BCnoYH2l_A">▶ YouTube에서 재생</a>
</p>

---

## 포스터

<p align="center">
  <a href="docs/poster.pdf">
    <img src="images/poster.png" alt="타요택시 포스터" width="720"/>
  </a>
</p>

<p align="center">
  <a href="docs/poster.pdf">포스터 PDF 보기</a>
  &nbsp;·&nbsp;
  <a href="docs/final-report.pdf">결과보고서 PDF</a>
</p>

---

## 주요 기능

- 현재 위치 자동 추적 기능
- 현재 위치 기반 500m 이내 랜드마크 리스트 제공 후 픽업 위치 선정
- 즐겨찾기 기능
- Firebase 연동을 통한 인증 및 실시간 데이터 처리

## 기술 스택

**프레임워크**
- Flutter (Dart)

**백엔드**
- Firebase Authentication — 로그인 / 회원가입
- Cloud Firestore — 호출·운행 실시간 데이터

**지도 / 위치**
- Google Places API — 목적지 자동완성, 음성 장소 추출
- Tmap API — 500m 이내 랜드마크 픽업 추천
- Naver Map SDK — 픽업 위치 지도
- Geolocator — 현재 위치 조회

## 플로우 차트

<p align="center">
  <img src="images/기능_흐름도.png" alt="기능 흐름도" width="720"/>
</p>

## 개발 팀원

| 이름 | 역할 | 주요 담당 업무 |
|------|------|----------------|
| 서정우 | 팀장 / 프론트엔드 | 전체 UI 디자인 및 화면 레이아웃, 즐겨찾기·이용 내역, 보고서 |
| 강유진 | 팀원 / 백엔드 | API 및 DB 연동, 로그인/회원가입, 랜드마크 기반 위치 탐색, 보고서 |
