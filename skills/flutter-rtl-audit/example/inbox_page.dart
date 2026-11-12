import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MaterialApp(home: InboxPage()));

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final count = 3;
    final date = DateFormat('d MMM yyyy').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Image.asset('assets/icons/arrow_back.png'),
        ),
        title: Text('$count messages', textAlign: TextAlign.left),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blueGrey],
          ),
        ),
        child: ListView(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 8, 8),
              padding: const EdgeInsets.only(left: 56, top: 12, bottom: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                border: Border(left: BorderSide(color: Colors.blue.shade700, width: 4)),
              ),
              child: Text('Your order is ready, $date'),
            ),
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Image.asset('assets/icons/chevron_right.png'),
                  ),
                  Positioned.fill(child: Image.asset('assets/icons/scroll_up.png')),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.person),
                Text(count == 1 ? 'item' : 'items'),
              ].reversed.toList(),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: TextField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Phone'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
