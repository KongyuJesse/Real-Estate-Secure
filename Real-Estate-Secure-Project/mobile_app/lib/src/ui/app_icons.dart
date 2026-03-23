import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class ResIcons {
  static const brand = SolarIconsBold.buildings;
  static const search = SolarIconsOutline.mapPointSearch;
  static const bell = SolarIconsOutline.bell;
  static const profile = SolarIconsOutline.userRounded;
  static const home = SolarIconsBold.homeSmile;
  static const map = SolarIconsOutline.map;
  static const listings = SolarIconsOutline.clipboardList;
  static const finance = SolarIconsOutline.walletMoney;
  static const secure = SolarIconsBold.shieldCheck;
  static const favorite = SolarIconsOutline.heart;
  static const share = SolarIconsOutline.share;
  static const back = SolarIconsOutline.altArrowLeft;
  static const check = SolarIconsOutline.verifiedCheck;
  static const location = SolarIconsOutline.mapPoint;
  static const phone = SolarIconsOutline.phoneRounded;
  static const sale = SolarIconsOutline.sale;
  static const rent = SolarIconsOutline.keySquare;
  static const building = SolarIconsOutline.buildings;
  static const land = SolarIconsOutline.mapPoint;
  static const house = SolarIconsOutline.homeSmile;
  static const apartment = SolarIconsOutline.buildings_2;
  static const commercial = SolarIconsOutline.caseRound;
  static const filter = SolarIconsOutline.filters;
  static const logout = SolarIconsOutline.logout;
  static const settings = SolarIconsOutline.settingsMinimalistic;
  static const task = SolarIconsOutline.caseRoundMinimalistic;
  static const server = SolarIconsOutline.cloudCheck;
  static const login = SolarIconsOutline.login;
  static const personAdd = SolarIconsOutline.userPlus;
  static const arrowRight = SolarIconsOutline.arrowRight;
  static const crown = SolarIconsOutline.starCircle;
  static const analytics = Icons.insights_rounded;
  static const support = SolarIconsOutline.headphonesRound;
  static const api = SolarIconsOutline.cloudStorage;
  static const photo = SolarIconsOutline.galleryWide;
  static const video = SolarIconsOutline.videoLibrary;
  static const company = SolarIconsOutline.buildings_3;
  static const wallet = SolarIconsOutline.walletMoney;
  static const identity = SolarIconsOutline.userId;
  static const star = SolarIconsOutline.starFall;
  static const security = SolarIconsOutline.lockPassword;
  static const membership = SolarIconsOutline.starCircle;
  static const fingerprint = Icons.fingerprint_rounded;
  static const quickUnlock = SolarIconsOutline.lockPassword;
  static const trust = Icons.verified_user_outlined;
  static const legal = Icons.gavel_rounded;
  static const receipt = Icons.receipt_long_rounded;
  static const document = Icons.description_outlined;
  static const upload = Icons.upload_rounded;
  static const eye = Icons.remove_red_eye_outlined;
  static const moneyIn = Icons.add_circle_outline_rounded;
  static const moneyOut = Icons.account_balance_outlined;
  static const vault = Icons.lock_outline_rounded;

  static IconData propertyType(String raw) {
    switch (raw) {
      case 'land':
      case 'agricultural':
        return land;
      case 'apartment':
        return apartment;
      case 'commercial':
      case 'industrial':
        return commercial;
      case 'house':
      default:
        return house;
    }
  }

  static IconData listingType(String raw) {
    switch (raw) {
      case 'rent':
      case 'lease':
        return rent;
      case 'sale':
      default:
        return sale;
    }
  }

  static IconData taskPriority(String raw) {
    switch (raw) {
      case 'urgent':
        return Icons.priority_high_rounded;
      case 'high':
        return SolarIconsOutline.shieldWarning;
      case 'medium':
        return SolarIconsOutline.clockCircle;
      default:
        return SolarIconsOutline.clipboardCheck;
    }
  }
}
