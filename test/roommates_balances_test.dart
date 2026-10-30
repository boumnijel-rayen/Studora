import 'package:flutter_test/flutter_test.dart';
import 'package:studora/features/roommates/models/roommate_models.dart';

const _alice = Roommate(id: 'a', name: 'Alice', phone: '', email: '', roomNumber: '1');
const _bob = Roommate(id: 'b', name: 'Bob', phone: '', email: '', roomNumber: '2');
const _carol = Roommate(id: 'c', name: 'Carol', phone: '', email: '', roomNumber: '3');

Expense _expense(
  double amount, {
  required String paidBy,
  required List<String> participants,
}) => Expense(
  id: 'e',
  title: 'Dépense',
  amount: amount,
  paidById: paidBy,
  paidByName: '',
  date: DateTime(2026, 10, 1),
  category: 'Autre',
  participantIds: participants,
);

void main() {
  test('splits an expense between its participants only', () {
    final balances = computeBalances(
      [_alice, _bob, _carol],
      [_expense(30, paidBy: 'a', participants: ['a', 'b'])],
    );

    expect(balances.length, 1);
    expect(balances.first.fromId, 'b');
    expect(balances.first.toId, 'a');
    expect(balances.first.amount, 15.0);
  });

  test('a member added later does not change an older expense', () {
    final before = computeBalances(
      [_alice, _bob],
      [_expense(30, paidBy: 'a', participants: ['a', 'b'])],
    );
    final after = computeBalances(
      [_alice, _bob, _carol],
      [_expense(30, paidBy: 'a', participants: ['a', 'b'])],
    );

    expect(after.single.amount, before.single.amount);
    expect(after.single.fromId, 'b');
  });

  test('a payer who is not a participant is owed the whole amount', () {
    final balances = computeBalances(
      [_alice, _bob],
      [_expense(20, paidBy: 'a', participants: ['b'])],
    );

    expect(balances.single.fromId, 'b');
    expect(balances.single.amount, 20.0);
  });

  test('a settlement clears the debt', () {
    final balances = computeBalances(
      [_alice, _bob],
      [
        _expense(30, paidBy: 'a', participants: ['a', 'b']),
        Expense(
          id: 's',
          title: 'Remboursement',
          amount: 15,
          paidById: 'b',
          paidByName: 'Bob',
          reimbursedToId: 'a',
          reimbursedToName: 'Alice',
          isSettlement: true,
          date: DateTime(2026, 10, 2),
          category: 'Remboursement',
        ),
      ],
    );

    expect(balances, isEmpty);
  });

  test('two members with the same name stay separate', () {
    const twin = Roommate(id: 'b2', name: 'Bob', phone: '', email: '', roomNumber: '4');
    final balances = computeBalances(
      [_alice, _bob, twin],
      [_expense(30, paidBy: 'b', participants: ['b', 'b2', 'a'])],
    );

    expect(balances.length, 2);
    expect(balances.map((b) => b.fromId).toSet(), {'a', 'b2'});
    expect(balances.every((b) => b.toId == 'b' && b.amount == 10.0), isTrue);
  });

  test('a former member still appears in the balances', () {
    const former = Roommate(
      id: 'c',
      name: 'Carol',
      phone: '',
      email: '',
      roomNumber: '3',
      isActive: false,
    );
    final balances = computeBalances(
      [_alice, former],
      [_expense(10, paidBy: 'a', participants: ['a', 'c'])],
    );

    expect(balances.single.fromPerson, 'Carol');
    expect(balances.single.amount, 5.0);
  });
}
