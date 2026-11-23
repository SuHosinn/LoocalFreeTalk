# LocalFreeTalk

온디바이스 오프라인 번역 모델을 활용한 **Flutter 기반 음성 번역 모바일 애플리케이션**입니다.  
네트워크 연결이 불안정하거나 오프라인인 상황에서도 실시간 음성 입력(`STT`) → 다국어 번역(`ML Kit`) → 음성 출력(`TTS`)이 가능한 경량 모바일 번역 앱을 목표로 구축했습니다.

---

## 1. 프로젝트 개요

- **프로젝트명:** LocalFreeTalk (온디바이스 오프라인 음성 번역 모바일 앱)
- **목적:** 네트워크 제약 환경이나 오프라인 상태에서도 실시간 음성 인식, 온디바이스 다국어 번역, 음성 합성을 끊김 없이 지원하는 모바일 번역 애플리케이션 구현
- **주요 지원 언어:** 영어(`English`), 한국어(`Korean`), 베트남어(`Vietnamese`) 간 상호 번역 및 음성 지원
- **배포 형태:** Android 릴리즈 APK(`app-release.apk`) 빌드 및 실기기 설치 검증

---

## 2. 기술 스택 및 개발 환경

| 구분 | 항목 | 상세 내용 및 적용 역할 |
| :--- | :--- | :--- |
| **Framework / Language** | **Flutter** (`Dart`, SDK `^3.13.7`) | 크로스플랫폼 UI 구성 및 비동기 상태 관리(`StatefulWidget`) |
| **On-Device Translation** | `google_mlkit_translation` (`^0.15.1`) | 언어별 오프라인 번역 모델 다운로드 및 기기 내 번역(`OnDeviceTranslator`) |
| **Speech to Text (STT)** | `speech_to_text` (`^7.5.0`) | 마이크 입력을 통한 실시간 음성 인식 및 로케일(`en_US`, `ko_KR`, `vi_VN`)별 처리 |
| **Text to Speech (TTS)** | `flutter_tts` (`^4.2.5`) | 번역 결과 텍스트의 타겟 언어(`en-US`, `ko-KR`, `vi-VN`) 음성 합성 출력 |
| **Android Build** | **Gradle / Kotlin DSL** (`build.gradle.kts`), **Java 17**, **Android NDK** (`30.0.16248370`) | Android SDK/NDK 구성, 릴리즈 APK 패키징, 권한 및 쿼리 설정 |
| **Environment** | **Windows**, **VS Code / Flutter CLI** | 프로젝트 빌드, 의존성 관리(`flutter pub get`), 실기기 배포 테스트 |

---

## 3. 주요 기능 및 구현 내용

1. **오프라인 AI 모델 자동 점검 및 다운로드 관리**
   - 앱 실행 및 언어 변경 시 `OnDeviceTranslatorModelManager`를 통해 선택된 출발어·도착어 및 지원 언어 모델의 다운로드 여부를 확인하고 누락된 모델을 순차 다운로드합니다.
   - 상단 상태 배지를 통해 모델 준비 상태(`Checking AI Models...`, `Downloading ... Model...`, `All Offline AI Models Ready`, 오류 시 재시도)를 직관적으로 안내합니다.

2. **음성 인식 → 번역 → 음성 출력 파이프라인**
   - 마이크 버튼 토글로 음성 인식을 시작·종료하고, 인식된 텍스트를 번역 함수로 전달합니다.
   - 번역 완료 시 화면에 결과를 출력하고 `flutter_tts`로 읽어주며, TTS 오류 발생 시에도 번역 결과 텍스트는 유지되도록 분리 처리했습니다.

3. **예외 방어 및 사용자 피드백 처리**
   - `MissingPluginException` 및 모델 초기화·음성 인식 예외를 포착하여 앱이 크래시되지 않고 상태 배지 및 안내 문구로 원인을 표시하도록 구현했습니다.

---

## 4. 지원 언어 및 로케일 매핑

- **English:** 번역 `TranslateLanguage.english` / STT `en_US` / TTS `en-US`
- **Korean (한국어):** 번역 `TranslateLanguage.korean` / STT `ko_KR` / TTS `ko-KR`
- **Vietnamese (Tiếng Việt):** 번역 `TranslateLanguage.vietnamese` / STT `vi_VN` / TTS `vi-VN`

---

## 5. 빌드 및 실행 방법

### 5.1 의존성 설치 및 릴리즈 APK 빌드

```bash
flutter clean
flutter pub get
flutter build apk --release
