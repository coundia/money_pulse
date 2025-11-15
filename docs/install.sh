flutter create jaayko
cd jaayko
 
# install deps
flutter pub add flutter_riverpod go_router sqflite path_provider uuid intl shared_preferences  path fl_chart
flutter pub add share_plus
flutter pub add path_provider printing pdf 
flutter pub add flutter_svg
flutter pub add flutter_secure_storage

mkdir -p assets/db
mkdir -p lib/domain/accounts/entities lib/domain/accounts/repositories
mkdir -p lib/domain/categories/entities lib/domain/categories/repositories
mkdir -p lib/domain/transactions/entities lib/domain/transactions/repositories
mkdir -p lib/domain/core
mkdir -p lib/application/usecases
mkdir -p lib/infrastructure/db lib/infrastructure/repositories
mkdir -p lib/presentation/app lib/presentation/features/home lib/presentation/features/transactions lib/presentation/features/categories lib/presentation/features/reports lib/presentation/widgets



flutter pub add flutter_native_splash
flutter pub add url_launcher
flutter pub add image_picker
flutter pub add transparent_image
flutter pub add image_picker  image_picker_android file_picker mime  crypto

# generate icons
#Just add : assets/logo/app_icon.png
dart run flutter_launcher_icons
dart run flutter_native_splash:create
