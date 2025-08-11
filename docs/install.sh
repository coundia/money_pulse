flutter create money_pulse
cd money_pulse
 
# install deps
flutter pub add flutter_riverpod go_router sqflite path_provider uuid intl shared_preferences  path fl_chart
flutter pub add share_plus

mkdir -p assets/db
mkdir -p lib/domain/accounts/entities lib/domain/accounts/repositories
mkdir -p lib/domain/categories/entities lib/domain/categories/repositories
mkdir -p lib/domain/transactions/entities lib/domain/transactions/repositories
mkdir -p lib/domain/core
mkdir -p lib/application/usecases
mkdir -p lib/infrastructure/db lib/infrastructure/repositories
mkdir -p lib/presentation/app lib/presentation/features/home lib/presentation/features/transactions lib/presentation/features/categories lib/presentation/features/reports lib/presentation/widgets
