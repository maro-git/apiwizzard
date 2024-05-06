import 'package:flutter/material.dart';

class Bubble extends StatelessWidget {
  final String message;
  final Color color;
  final bool isMe;
  final Widget? child;

  const Bubble(
      {Key? key,
      required this.message,
      required this.color,
      required this.isMe,
      this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: isMe ? Radius.circular(16.0) : Radius.circular(0.0),
            topRight: isMe ? Radius.circular(0.0) : Radius.circular(16.0),
            bottomLeft: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
              ),
            ),
            SizedBox(height: 8.0),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
