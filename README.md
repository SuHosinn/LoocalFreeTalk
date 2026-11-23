# localfreetalk

# LocalFreeTalk

온디바이스 오프라인 번역 모델을 활용한 **Flutter 기반 음성 번역 모바일 애플리케이션**입니다.  
네트워크 환경이 불안정하거나 오프라인인 상황에서도 음성 입력(`STT`) → 다국어 번역(`ML Kit`) → 음성 출력(`TTS`) 흐름을 지원하도록 구성했습니다.

---

## 주요 기능

- **오프라인 번역 모델 자동 관리:** 선택된 출발어/도착어 및 지원 언어 모델의 다운로드 여부를 확인하고 누락된 모델을 순차 다운로드합니다.
- **실시간 음성 인식 및 번역:** 마이크 버튼 토글로 음성을 인식한 뒤 번역 결과를 화면에 출력합니다.
- **음성 합성 출력 (TTS):** 번역된 텍스트를 타겟 언어 로케일에 맞춰 읽어주며, TTS 오류 발생 시에도 번역 결과 텍스트는 유지됩니다.
- **예외 방어 및 상태 안내:** 모델 준비 상태(`Checking AI Models...`, `Downloading ... Model...`, `All Offline AI Models Ready`)와 오류/재시도 상태를 상단 배지로 안내합니다.

---

## 지원 언어

- **English** (`en_US` / `en-US`)
- **Korean (한국어)** (`ko_KR` / `ko-KR`)
- **Vietnamese (Tiếng Việt)** (`vi_VN` / `vi-VN`)

---

## 기술 스택 및 개발 환경

| 구분 | 항목 | 비고 |
| :--- | :--- | :--- |
| **Framework / Language** | Flutter (`Dart`, SDK `^3.13.7`) | 크로스플랫폼 UI 및 상태 관리 |
| **On-Device Translation** | `google_mlkit_translation` (`^0.15.1`) | 오프라인 번역 모델 다운로드 및 번역 |
| **Speech to Text (STT)** | `speech_to_text` (`^7.5.0`) | 마이크 음성 인식 |
| **Text to Speech (TTS)** | `flutter_tts` (`^4.2.5`) | 번역 결과 음성 출력 |
| **Android Build** | Gradle (Kotlin DSL), Java 17, NDK `30.0.16248370` | Android 릴리즈 APK 빌드 |
| **Environment** | Windows, VS Code, Flutter CLI | 개발 및 실기기 배포 테스트 |

---

## 빌드 및 실행 방법

### 1. 의존성 설치 및 릴리즈 APK 빌드

```bash
flutter clean
flutter pub get
flutter build apk --release
