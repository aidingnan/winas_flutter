import 'package:crypto/crypto.dart';

/// A sink used to get a digest value out of `Hash.startChunkedConversion`.
class DigestSink extends Sink<Digest> {
  /// The value added to the sink, if any.
  Digest get value {
    assert(_value != null);
    return _value;
  }

  Digest _value;

  /// Adds [value] to the sink.
  ///
  /// Unlike most sinks, this may only be called once.
  @override
  void add(Digest value) {
    assert(_value == null);
    _value = value;
  }

  @override
  void close() {
    assert(_value != null);
  }
}

List<int> bufferFrom(String str) {
  List<int> bufferList = [];
  for (int i = 0; i < str.length; i += 2) {
    final a = int.parse(str.substring(i, i + 2), radix: 16);
    print(a);
    bufferList.add(a);
  }
  return bufferList;
}

/// combine two sha256 value
String combineHash(String h1, String h2) {
  List<int> b1 = bufferFrom(h1);
  List<int> b2 = bufferFrom(h2);

  final ds = DigestSink();
  final s = sha256.startChunkedConversion(ds);

  s.add(b1);
  s.add(b2);
  s.close();
  return ds.value.toString();
}

main() {
  print(combineHash(
      '64a2dfbb176ef91d4cd2a9bce757f0f55ad00e53326afc7fbc3d6df53c6e8bea',
      '5f2ddc28464dec04a5e9dca36ba73e2e6dad8d0feea6ee88afd8db29bdee9ac0'));
  // expect 8fc79a04bacc735060e8fa60677a60eef5d1a7b10dea1f1a741a19ad853261b3
}
