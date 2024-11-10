import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteContactsScreen extends StatefulWidget {
  @override
  _InviteContactsScreenState createState() => _InviteContactsScreenState();
}

class _InviteContactsScreenState extends State<InviteContactsScreen> {
  List<Contact> _contacts = [];
  List<Contact> _selectedContacts = [];

  @override
  void initState() {
    super.initState();
    _requestPermissionAndFetchContacts();
  }

  Future<void> _requestPermissionAndFetchContacts() async {
    PermissionStatus permissionStatus = await _getContactPermission();
    if (permissionStatus == PermissionStatus.granted) {
      _fetchContacts();
    } else {
      _handleInvalidPermissions(permissionStatus);
    }
  }

  Future<PermissionStatus> _getContactPermission() async {
    PermissionStatus permission = await Permission.contacts.status;
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.permanentlyDenied &&
        permission != PermissionStatus.limited) {
        PermissionStatus status = await Permission.contacts.request();
        return status;
    } else {
        return permission;
    }
}


  void _handleInvalidPermissions(PermissionStatus status) {
    if (status == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Contact permissions are denied'),
      ));
    } else if (status == PermissionStatus.permanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Contact permissions are permanently denied, please enable in settings'),
      ));
    }
  }

  void _fetchContacts() async {
    Iterable<Contact> contacts = await ContactsService.getContacts();
    setState(() {
      _contacts = contacts.toList();
    });
  }

  void _sendInvitations() {
    for (var contact in _selectedContacts) {
      String? phone = contact.phones!.isNotEmpty ? contact.phones!.first.value : null;
      if (phone != null) {
        _sendSMSInvitation(phone);
      }
    }
  }

  void _sendSMSInvitation(String phoneNumber) async {
    String message = 'Join me on this awesome app! Use my referral code: ABC123';
    Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      print('Could not launch $smsUri');
    }
  }

  void _onContactTap(Contact contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  Widget _buildContactList() {
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        Contact contact = _contacts[index];
        bool isSelected = _selectedContacts.contains(contact);
        return ListTile(
          leading: CircleAvatar(
            child: Text(contact.initials()),
          ),
          title: Text(contact.displayName ?? ''),
          subtitle: Text(contact.phones!.isNotEmpty ? contact.phones!.first.value! : ''),
          trailing: isSelected ? Icon(Icons.check_box) : Icon(Icons.check_box_outline_blank),
          onTap: () => _onContactTap(contact),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Invite Contacts'),
          actions: [
            IconButton(
              icon: Icon(Icons.send),
              onPressed: _selectedContacts.isEmpty ? null : _sendInvitations,
            )
          ],
        ),
        body: _contacts.isEmpty
            ? Center(child: CircularProgressIndicator())
            : _buildContactList());
  }
}
