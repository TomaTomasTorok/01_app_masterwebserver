import 'package:flutter/material.dart';

import '../../model/wokrplace.dart';


class WorkplaceForm extends StatefulWidget {
  final void Function(Workplace workplace, [int? index]) onSubmit;
  final Workplace? initialWorkplace;
  final int? index;

  WorkplaceForm({required this.onSubmit, this.initialWorkplace, this.index});

  @override
  _WorkplaceFormState createState() => _WorkplaceFormState();
}

class _WorkplaceFormState extends State<WorkplaceForm> {
  late TextEditingController _nameController;
  late TextEditingController _ipAddressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialWorkplace?.name ?? '');
    _ipAddressController = TextEditingController(text: widget.initialWorkplace?.ipAddress ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipAddressController.dispose();
    super.dispose();
  }

  void _submit() {
    final Workplace newWorkplace = Workplace(
      name: _nameController.text,
      ipAddress: _ipAddressController.text,
      products: widget.initialWorkplace?.products ?? [],
    );
    widget.onSubmit(newWorkplace, widget.index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.index == null ? 'Add Workplace' : 'Edit Workplace'),
      ),
      body: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Workplace Name'),
            ),
            TextField(
              controller: _ipAddressController,
              decoration: InputDecoration(labelText: 'IP Address'),
            ),
            ElevatedButton(
              onPressed: _submit,
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
