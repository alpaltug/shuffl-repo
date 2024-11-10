import 'package:flutter/cupertino.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:azlistview/azlistview.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';



class ContactInfo extends ISuspensionBean {
  final Contact contact;
  String namePinyin; // Name converted to Pinyin
  String tagIndex;   // First letter of the name


  ContactInfo({
    required this.contact,
    required this.namePinyin,
    required this.tagIndex,
  });

  @override
  String getSuspensionTag() => tagIndex;
}

class InviteContactsScreen extends StatefulWidget {
  const InviteContactsScreen({Key? key}) : super(key: key);

  @override
  _InviteContactsScreenState createState() => _InviteContactsScreenState();
}

class _InviteContactsScreenState extends State<InviteContactsScreen> {
  List<ContactInfo> _contacts = [];
  List<ContactInfo> _filteredContacts = [];
  List<ContactInfo> _selectedContacts = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  final ItemScrollController _itemScrollController = ItemScrollController();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndFetchContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterContacts(_searchController.text);
  }

  void _filterContacts(String searchTerm) {
    if (searchTerm.isEmpty) {
      setState(() {
        _filteredContacts = List<ContactInfo>.from(_contacts);
      });
    } else {
      setState(() {
        _filteredContacts = _contacts.where((contactInfo) {
          String name = contactInfo.contact.displayName?.toLowerCase() ?? '';
          return name.contains(searchTerm.toLowerCase());
        }).toList();
      });
    }
    SuspensionUtil.setShowSuspensionStatus(_filteredContacts);
  }

  Future<void> _requestPermissionAndFetchContacts() async {
    PermissionStatus permissionStatus = await _getContactPermission();
    if (permissionStatus == PermissionStatus.granted) {
      _fetchContacts();
    } else {
      await _handleInvalidPermissions(permissionStatus);
    }
  }

  Future<String> _getReferralCode() async {
    String? referralCode;
    String uid = _auth.currentUser!.uid;

    // Check if the user already has a referral code
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc['referralCode'] != null) {
        referralCode = userDoc['referralCode'];
    } else {
        // Generate a unique referral code
        referralCode = await _generateUniqueReferralCode();

        // Save the referral code to the user's document
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'referralCode': referralCode,
        });

        // Create a new referral code document
        await FirebaseFirestore.instance.collection('referralCodes').doc(referralCode).set({
        'creatorParticipant': uid,
        'users': [],
        });
    }
    return referralCode!;
}

String _generateReferralCode() {
  const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  Random random = Random();
  return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
}

Future<String> _generateUniqueReferralCode() async {
  String code;
  bool exists = true;

  do {
    code = _generateReferralCode();
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('referralCodes').doc(code).get();
    exists = doc.exists;
  } while (exists);

  return code;
}



  

  Future<PermissionStatus> _getContactPermission() async {
    PermissionStatus permission = await Permission.contacts.status;
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.permanentlyDenied) {
      PermissionStatus status = await Permission.contacts.request();
      return status;
    } else {
      return permission;
    }
  }

  Future<void> _handleInvalidPermissions(PermissionStatus status) async {
    bool isPermanentlyDenied = await Permission.contacts.isPermanentlyDenied;
    if (status == PermissionStatus.denied) {
        _showPermissionDeniedDialog(
        'Contact permissions are denied.',
        isPermanentlyDenied: isPermanentlyDenied,
        );
    } else if (status == PermissionStatus.permanentlyDenied) {
        _showPermissionDeniedDialog(
        'Contact permissions are permanently denied, please enable in settings.',
        isPermanentlyDenied: isPermanentlyDenied,
        );
    }
}

  void _showPermissionDeniedDialog(String message, {required bool isPermanentlyDenied}) {
    showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
        title: const Text('Permission Denied'),
        content: Text(message),
        actions: [
            CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
            ),
            if (isPermanentlyDenied)
            CupertinoDialogAction(
                child: const Text('Settings'),
                onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
                },
            ),
        ],
        ),
    );
}

  void _fetchContacts() async {
    Iterable<Contact> contacts = await ContactsService.getContacts();
    List<ContactInfo> contactInfos = [];

    for (var contact in contacts) {
      String name = contact.displayName ?? '';
      if (name.isEmpty) continue;

      // Convert the name to Pinyin or lowercase
      String namePinyin = name.toLowerCase();

      String tagIndex = namePinyin[0].toUpperCase();
      if (!RegExp(r'[A-Z]').hasMatch(tagIndex)) {
        tagIndex = '#';
      }

      contactInfos.add(ContactInfo(
        contact: contact,
        namePinyin: namePinyin,
        tagIndex: tagIndex,
      ));
    }

    // Sort the list
    SuspensionUtil.sortListBySuspensionTag(contactInfos);
    SuspensionUtil.setShowSuspensionStatus(contactInfos);

    setState(() {
      _contacts = contactInfos;
      _filteredContacts = List<ContactInfo>.from(_contacts);
    });
  }

  void _sendInvitations() async {
    if (_selectedContacts.isEmpty) {
        _showNoContactsSelectedDialog();
        return;
    }

    String referralCode = await _getReferralCode();

    String message =
        'Shuffl lets you split rideshare costs! It is a carpool app that matches you with others that will be heading the same way as you at the same time based on your preferences. Use my referral code $referralCode when signing up to get rewards! Download the app here: https://apps.apple.com/us/app/shuffl-mobility/id6670162779';

    Share.share(
        message,
        subject: 'Join me on Shuffl!',
    );
}

  void _showNoContactsSelectedDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('No Contacts Selected'),
        content: const Text('Please select at least one contact to invite.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _onContactTap(ContactInfo contactInfo) {
    setState(() {
      if (_selectedContacts.contains(contactInfo)) {
        _selectedContacts.remove(contactInfo);
      } else {
        _selectedContacts.add(contactInfo);
      }
    });
  }

  Widget _buildAvatar(String initials) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildList() {
    return AzListView(
      data: _filteredContacts,
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        ContactInfo model = _filteredContacts[index];
        Contact contact = model.contact;
        bool isSelected = _selectedContacts.contains(model);

        return Column(
          children: [
            if (model.isShowSuspension)
              Container(
                height: 40,
                width: double.infinity,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 16),
                color: CupertinoColors.systemGrey5,
                child: Text(
                  model.getSuspensionTag(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            CupertinoListTile(
              leading: _buildAvatar(contact.initials()),
              title: Text(
                contact.displayName ?? '',
                style: const TextStyle(
                  color: CupertinoColors.black,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                contact.phones!.isNotEmpty ? contact.phones!.first.value! : '',
                style: const TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 14,
                ),
              ),
              trailing: Icon(
                isSelected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: isSelected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.inactiveGray,
                size: 28,
              ),
              onTap: () => _onContactTap(model),
            ),
          ],
        );
      },
      itemScrollController: _itemScrollController,
      indexBarOptions: IndexBarOptions(
        needRebuild: true,
        selectTextStyle: const TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.bold,
        ),
        selectItemDecoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: CupertinoColors.activeBlue,
        ),
        indexHintAlignment: Alignment.centerRight,
        indexHintOffset: const Offset(-20, 0),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'Invite Contacts',
          style: TextStyle(color: CupertinoColors.black),
        ),
        backgroundColor: kBackgroundColor,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.share,
            color: CupertinoColors.black,
          ),
          onPressed: _sendInvitations,
        ),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search',
            ),
            Expanded(
              child: _buildList(),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom CupertinoListTile since it's not a built-in widget
class CupertinoListTile extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const CupertinoListTile({
    Key? key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 16),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}