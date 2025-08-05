import 'package:flutter/material.dart';

class AppIcons {
  // Transaction Type Icons
  static const IconData purchase = Icons.shopping_cart_outlined;
  static const IconData sale = Icons.trending_up_outlined;
  
  // Action Icons
  static const IconData add = Icons.add;
  static const IconData sell = Icons.sell_outlined;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outlined;
  
  // Navigation Icons
  static const IconData home = Icons.home_outlined;
  static const IconData portfolio = Icons.account_balance_wallet_outlined;
  static const IconData transactions = Icons.receipt_long_outlined;
  static const IconData reports = Icons.assessment_outlined;
  static const IconData export = Icons.file_download_outlined;
  static const IconData settings = Icons.settings_outlined;
  
  // Status Icons
  static const IconData open = Icons.circle_outlined;
  static const IconData closed = Icons.check_circle_outlined;
  
  // Other Icons
  static const IconData calendar = Icons.calendar_today_outlined;
  static const IconData refresh = Icons.refresh_outlined;
  static const IconData currency = Icons.euro_outlined;
  
  // Get transaction type icon with color
  static Icon getTransactionIcon(bool isSale, {double size = 24}) {
    return Icon(
      isSale ? sale : purchase,
      color: isSale ? Colors.red : Colors.green,
      size: size,
    );
  }
  
  // Get transaction type icon for CircleAvatar
  static Widget getTransactionAvatar(bool isSale, {double size = 40}) {
    return CircleAvatar(
      backgroundColor: isSale ? Colors.red : Colors.green,
      radius: size / 2,
      child: Icon(
        isSale ? sale : purchase,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}