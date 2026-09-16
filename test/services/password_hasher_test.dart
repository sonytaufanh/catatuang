import 'package:flutter_test/flutter_test.dart';

import 'package:catatuang/services/password_hasher.dart';

void main() {
  test('hash produces the pbkdf2 format and verifies the correct value', () async {
    final stored = await PasswordHasher.hash('1234');
    expect(PasswordHasher.isHashed(stored), isTrue);
    expect(stored.startsWith('pbkdf2\$'), isTrue);
    expect(await PasswordHasher.verify('1234', stored), isTrue);
  });

  test('verify rejects wrong value and malformed hashes', () async {
    final stored = await PasswordHasher.hash('secret-password');
    expect(await PasswordHasher.verify('secret-passwerd', stored), isFalse);
    expect(await PasswordHasher.verify('secret-password', 'plain'), isFalse);
    expect(await PasswordHasher.verify('x', 'pbkdf2\$bad'), isFalse);
  });

  test('same value hashes differently (random salt)', () async {
    final a = await PasswordHasher.hash('1234');
    final b = await PasswordHasher.hash('1234');
    expect(a, isNot(equals(b)));
    expect(await PasswordHasher.verify('1234', a), isTrue);
    expect(await PasswordHasher.verify('1234', b), isTrue);
  });
}
