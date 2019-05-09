import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../redux/redux.dart';
import '../photos/GridPhoto.dart';

List<String> photoMagic = ['JPEG', 'GIF', 'PNG', 'BMP'];

List<String> thumbMagic = ['JPEG', 'GIF', 'PNG', 'BMP', 'PDF'];

showPhoto(BuildContext ctx, Entry entry, Uint8List thumbData) {
  Navigator.push(
    ctx,
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              entry.name,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.normal,
              ),
            ),
            elevation: 2.0,
            brightness: Brightness.light,
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black38),
          ),
          body: SizedBox.expand(
            child: Hero(
              tag: entry.uuid,
              child: GridPhoto(
                updateOpacity: (double op) => {},
                photo: entry,
                thumbData: thumbData,
                toggleTitle: ({bool show}) => {},
                showTitle: true,
              ),
            ),
          ),
        );
      },
    ),
  );
}
