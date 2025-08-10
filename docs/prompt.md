Base on this schemas create an app to manage personal finances with good UI/UX, It takes seconds to record daily transactions. Put them into clear and visualized categories such as Expense: Food, Shopping or Income: Salary, Gift.One report to give a clear view on your spending patterns. Understand where your money comes and goes with easy-to-read graphs.User must must view current balance ontop bar of app, create all view step by step 


I want always use console to create file and install deps, give all command



touch lib/domain/accounts/repositories/account_repository.dart

import '../entities/account.dart';

abstract class AccountRepository {
  Future<Account> create(Account account);
  Future<void> update(Account account);
  Future<Account?> findById(String id);
  Future<Account?> findDefault();
  Future<List<Account>> findAllActive();
  Future<void> setDefault(String id);
  Future<void> softDelete(String id);
}
 

 - Add a header to select a month ( prev month current month and next month), with good ui in transaction too
 
 

 