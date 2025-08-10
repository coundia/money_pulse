flutter create money_pulse
cd money_pulse

cat > pubspec.yaml <<'YAML'
name: money_pulse
description: Personal finance app with ultra-fast entry, clear categories, and visual reports
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  sqflite: ^2.3.3
  path: ^1.9.0
  path_provider: ^2.1.3
  intl: ^0.19.0
  uuid: ^4.4.0
  fl_chart: ^0.68.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/db/schema_v1.sql
YAML

flutter pub get
