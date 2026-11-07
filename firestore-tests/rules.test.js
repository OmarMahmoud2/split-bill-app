// Firestore rules tests. Run with `npm test` (starts the emulator).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;

const HOST = 'host-uid';
const FRIEND = 'friend-uid';
const STRANGER = 'stranger-uid';
const ADMIN = 'admin-uid';
const GUEST = 'guest-anon-uid';

const google = (uid) => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'google.com' } }).firestore();
const guest = () => env.authenticatedContext(GUEST, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const bill = {
  hostId: HOST,
  storeName: 'Cafe',
  participants_uids: [HOST, FRIEND],
  participants: [
    { id: HOST, name: 'Host', uid: HOST, status: 'PAID' },
    { id: FRIEND, name: 'Friend', uid: FRIEND, status: 'PENDING' },
    { id: 'walk-in-1', name: 'Walk-in', status: 'PENDING' },
  ],
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-split-bill',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', HOST), { displayName: 'Host', phoneNumber: '+201000000001', fcmToken: 't1', points: 3 });
    await setDoc(doc(db, 'users', FRIEND), { displayName: 'Friend', phoneNumber: '+201000000002', points: 3 });
    await setDoc(doc(db, 'users', ADMIN), { displayName: 'Admin', isAdmin: true });
    await setDoc(doc(db, 'users', 'suspended-uid'), { displayName: 'Banned', suspended: true });
    await setDoc(doc(db, 'users', 'fresh-uid'), { fcmToken: 'x' });
    await setDoc(doc(db, 'bills', 'b1'), bill);
    await setDoc(doc(db, 'publicProfiles', HOST), { displayName: 'Host', customPaymentMethods: [] });
    await setDoc(doc(db, 'phoneClaims', '+201000000001'), { uid: HOST });
    await setDoc(doc(db, 'groups', 'g1'), {
      name: 'Dahab trip', createdBy: HOST, members: [], memberIds: [HOST, FRIEND, 'guest-member'],
      type: 'trip', currency: 'USD', budgetMinor: 120000, simplifyDebts: true,
    });
    await setDoc(doc(db, 'groups', 'legacy'), { name: 'Old', createdBy: HOST, members: [], memberIds: [HOST] });
    await setDoc(doc(db, 'bills', 'gb1'), { ...bill, groupId: 'g1', date: Timestamp.now(), participants_uids: [HOST] });
    await setDoc(doc(db, 'groups', 'g1', 'payments', 'gp1'), {
      kind: 'payment', from: FRIEND, to: HOST, amountMinor: 500, currency: 'USD', method: 'cash',
      groupId: 'g1', participants_uids: [FRIEND, HOST], createdBy: FRIEND, createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'payments', 'p1'), {
      kind: 'iou', from: FRIEND, to: HOST, amountMinor: 2000, currency: 'USD', method: 'iou',
      participants_uids: [FRIEND, HOST], createdBy: HOST, createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'payments', 'old'), {
      kind: 'payment', from: HOST, to: FRIEND, amountMinor: 100, currency: 'USD', method: 'cash',
      participants_uids: [FRIEND, HOST], createdBy: HOST,
      createdAt: Timestamp.fromMillis(Date.now() - 2 * 24 * 3600 * 1000),
    });
  });
});

describe('users', () => {
  it('denies unauthenticated reads', async () => {
    await assertFails(getDoc(doc(anon(), 'users', HOST)));
  });

  it('denies listing users to non-admins', async () => {
    await assertFails(getDocs(collection(google(STRANGER), 'users')));
    await assertFails(getDocs(query(collection(google(STRANGER), 'users'), where('phoneNumber', '==', '+201000000001'))));
  });

  it('allows admins to list users', async () => {
    await assertSucceeds(getDocs(collection(google(ADMIN), 'users')));
  });

  it('lets non-anonymous active users get another user by id (1.2.0 still reads them)', async () => {
    await assertSucceeds(getDoc(doc(google(FRIEND), 'users', HOST)));
    await assertSucceeds(getDoc(doc(google(HOST), 'users', HOST)));
    await assertSucceeds(getDoc(doc(google(ADMIN), 'users', HOST)));
  });

  it('denies anonymous guests and suspended users reading other users docs', async () => {
    await assertFails(getDoc(doc(guest(), 'users', HOST)));
    await assertFails(getDoc(doc(guest(), 'users', GUEST)));
    await assertFails(getDoc(doc(google('suspended-uid'), 'users', HOST)));
    // A suspended user still reads their own doc (to see the state).
    await assertSucceeds(getDoc(doc(google('suspended-uid'), 'users', 'suspended-uid')));
  });

  it('denies self-granting points', async () => {
    await assertFails(updateDoc(doc(google(HOST), 'users', HOST), { points: increment(1) }));
    await assertFails(updateDoc(doc(google(HOST), 'users', HOST), { points: 7 }));
  });

  it('denies self-granting premium or admin', async () => {
    await assertFails(updateDoc(doc(google(HOST), 'users', HOST), { isPremium: true }));
    await assertFails(updateDoc(doc(google(HOST), 'users', HOST), { isAdmin: true }));
  });

  it('allows the one-time welcome grant on a doc without points', async () => {
    await assertSucceeds(setDoc(doc(google('fresh-uid'), 'users', 'fresh-uid'), { phoneNumber: '+1', points: 7 }, { merge: true }));
    await assertSucceeds(setDoc(doc(google('new-uid'), 'users', 'new-uid'), { phoneNumber: '+1', points: 7 }));
    await assertFails(setDoc(doc(google('new2-uid'), 'users', 'new2-uid'), { points: 500 }));
  });

  it('allows normal profile edits', async () => {
    await assertSucceeds(updateDoc(doc(google(HOST), 'users', HOST), { displayName: 'New', fcmToken: 't2' }));
  });

  it('denies anonymous guests writing user docs', async () => {
    await assertFails(setDoc(doc(guest(), 'users', GUEST), { displayName: 'x' }));
  });

  it('lets admins set points', async () => {
    await assertSucceeds(updateDoc(doc(google(ADMIN), 'users', HOST), { points: 50 }));
  });
});

describe('bills', () => {
  it('denies unauthenticated reads', async () => {
    await assertFails(getDoc(doc(anon(), 'bills', 'b1')));
  });

  it('allows anonymous guests to open a shared bill by id', async () => {
    await assertSucceeds(getDoc(doc(guest(), 'bills', 'b1')));
  });

  it('denies listing all bills', async () => {
    await assertFails(getDocs(collection(google(STRANGER), 'bills')));
    await assertFails(getDocs(collection(guest(), 'bills')));
  });

  it('allows listing your own bills', async () => {
    await assertSucceeds(getDocs(query(collection(google(FRIEND), 'bills'), where('participants_uids', 'array-contains', FRIEND))));
    await assertSucceeds(getDocs(query(collection(google(HOST), 'bills'), where('hostId', '==', HOST))));
  });

  it('denies listing someone else\'s bills', async () => {
    await assertFails(getDocs(query(collection(google(STRANGER), 'bills'), where('participants_uids', 'array-contains', FRIEND))));
  });

  const withStatus = (i, status) => bill.participants.map((p, k) => (k === i ? { ...p, status } : p));

  it('lets a bill member update payment state only', async () => {
    await assertSucceeds(updateDoc(doc(google(FRIEND), 'bills', 'b1'), { participants: withStatus(1, 'REVIEW') }));
    await assertSucceeds(updateDoc(doc(google(HOST), 'bills', 'b1'), { participants: withStatus(2, 'PAID') }));
  });

  it('denies anonymous guests writing bills directly (they use the backend)', async () => {
    await assertFails(updateDoc(doc(guest(), 'bills', 'b1'), { participants: withStatus(2, 'REVIEW') }));
    await assertFails(updateDoc(doc(anon(), 'bills', 'b1'), { participants: withStatus(2, 'REVIEW') }));
  });

  it('denies non-members and suspended users writing payment state', async () => {
    await assertFails(updateDoc(doc(google(STRANGER), 'bills', 'b1'), { participants: withStatus(2, 'PAID') }));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'bills', 'bs'), { ...bill, participants_uids: [HOST, 'suspended-uid'] });
    });
    await assertFails(updateDoc(doc(google('suspended-uid'), 'bills', 'bs'), { participants: withStatus(2, 'PAID') }));
  });

  it('denies members changing list length or participant identity', async () => {
    const f = (b) => updateDoc(doc(google(FRIEND), 'bills', 'b1'), b);
    await assertFails(f({ participants: bill.participants.slice(0, 2) }));
    await assertFails(f({ participants: [...bill.participants, { name: 'Extra', status: 'PENDING' }] }));
    // Re-pointing an entry at someone else, or renaming it.
    await assertFails(f({ participants: bill.participants.map((p, k) => (k === 2 ? { ...p, id: FRIEND } : p)) }));
    await assertFails(f({ participants: bill.participants.map((p, k) => (k === 1 ? { ...p, name: 'Renamed' } : p)) }));
    await assertFails(f({ participants: bill.participants.map((p, k) => (k === 0 ? { name: 'Host', status: 'PAID', uid: HOST } : p)) }));
    await assertFails(f({ participants: [bill.participants[1], bill.participants[0], bill.participants[2]] }));
  });

  // The exact 1.2.0 member write (participant_bill_screen.dart on main): copy
  // the list, set paymentProof/status/paymentTime on my own entry, write the
  // whole list back. Entries carry the usual share fields.
  const full = (n) => Array.from({ length: n }, (_, i) => ({
    id: i === 0 ? HOST : i === 1 ? FRIEND : `p${i}`, name: `P${i}`, uid: i === 0 ? HOST : i === 1 ? FRIEND : undefined,
    amount: 10 + i, phoneNumber: `+2010000000${i}`, photoUrl: `https://x/${i}.jpg`, status: i === 0 ? 'PAID' : 'PENDING', isPaid: i === 0,
  })).map((p) => Object.fromEntries(Object.entries(p).filter(([, v]) => v !== undefined)));
  const seed = (id, participants) => env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'bills', id), { ...bill, participants });
  });
  const mine = (list, patch) => list.map((p, k) => (k === 1 ? { ...p, ...patch } : p));

  it('1.2.0 member mark-paid shapes keep working', async () => {
    const list = full(5);
    await seed('c1', list);
    const ref = doc(google(FRIEND), 'bills', 'c1');
    // With proof.
    await assertSucceeds(updateDoc(ref, { participants: mine(list, { paymentProof: 'QUJD', status: 'REVIEW', paymentTime: Timestamp.now() }) }));
    // Without proof (key written as null).
    await seed('c2', list);
    await assertSucceeds(updateDoc(doc(google(FRIEND), 'bills', 'c2'), { participants: mine(list, { paymentProof: null, status: 'REVIEW', paymentTime: Timestamp.now() }) }));
  });

  it('2.0 member mark-paid shape (adds paymentMethod) works', async () => {
    const list = full(5);
    await seed('c3', list);
    await assertSucceeds(updateDoc(doc(google(FRIEND), 'bills', 'c3'), {
      participants: mine(list, { paymentProof: 'data:image/jpeg;base64,QUJD', status: 'REVIEW', paymentTime: Timestamp.now(), paymentMethod: 'InstaPay' }),
    }));
  });

  it('denies a member changing anything but payment keys on any entry', async () => {
    const list = full(5);
    await seed('c4', list);
    const f = (participants) => updateDoc(doc(google(FRIEND), 'bills', 'c4'), { participants });
    const other = (patch) => list.map((p, k) => (k === 3 ? { ...p, ...patch } : p));
    await assertFails(f(other({ amount: 0 })));
    await assertFails(f(other({ uid: FRIEND })));
    await assertFails(f(other({ phoneNumber: '+1' })));
    await assertFails(f(other({ photoUrl: 'https://evil/x.jpg' })));
    await assertFails(f(other({ isPaid: true })));
    await assertFails(f(mine(list, { amount: 1 })));
    await assertFails(f(mine(list, { status: 'REVIEW', isPaid: true })));
    await assertFails(f(mine(list, { status: 'REVIEW', extra: 1 })));
    await assertFails(f(mine(list, { status: 'PAID' })));
    // The host may still change anything on an entry (identity aside).
    await assertSucceeds(updateDoc(doc(google(HOST), 'bills', 'c4'), { participants: other({ amount: 99, isPaid: true, status: 'PAID' }) }));
  });

  it('member direct writes stop above 12 participants; host and backend path cover big bills', async () => {
    const twelve = full(12);
    await seed('t12', twelve);
    await assertSucceeds(updateDoc(doc(google(FRIEND), 'bills', 't12'), { participants: mine(twelve, { status: 'REVIEW' }) }));
    const many = full(30);
    await seed('big', many);
    // Member: denied even for a pure payment change (use the backend).
    await assertFails(updateDoc(doc(google(FRIEND), 'bills', 'big'), { participants: mine(many, { status: 'REVIEW' }) }));
    // Host: allowed as before.
    await assertSucceeds(updateDoc(doc(google(HOST), 'bills', 'big'), { participants: many.map((p, i) => (i === 25 ? { ...p, status: 'PAID', isPaid: true } : p)) }));
  });

  it('denies members changing other fields', async () => {
    await assertFails(updateDoc(doc(google(FRIEND), 'bills', 'b1'), { storeName: 'Hacked' }));
    await assertFails(updateDoc(doc(google(FRIEND), 'bills', 'b1'), { participants_uids: [HOST, FRIEND, STRANGER] }));
    await assertFails(updateDoc(doc(google(FRIEND), 'bills', 'b1'), { participants: withStatus(1, 'PAID'), hostId: FRIEND }));
  });

  it('denies unauthenticated updates', async () => {
    await assertFails(updateDoc(doc(anon(), 'bills', 'b1'), { participants: bill.participants }));
  });

  it('only full users can create bills they host', async () => {
    await assertSucceeds(setDoc(doc(google(HOST), 'bills', 'b2'), { ...bill }));
    await assertFails(setDoc(doc(google(STRANGER), 'bills', 'b3'), { ...bill }));
    await assertFails(setDoc(doc(guest(), 'bills', 'b4'), { ...bill, hostId: GUEST }));
  });
});

describe('publicProfiles', () => {
  it('is readable by signed-in users and guests, not anonymous visitors', async () => {
    await assertSucceeds(getDoc(doc(guest(), 'publicProfiles', HOST)));
    await assertSucceeds(getDoc(doc(google(FRIEND), 'publicProfiles', HOST)));
    await assertFails(getDoc(doc(anon(), 'publicProfiles', HOST)));
  });

  it('only accepts the owner writing allowed keys', async () => {
    await assertSucceeds(setDoc(doc(google(FRIEND), 'publicProfiles', FRIEND), { displayName: 'F', photoUrl: null, customPaymentMethods: [], updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(google(FRIEND), 'publicProfiles', FRIEND), { displayName: 'F', phoneNumber: '+1' }));
    await assertFails(setDoc(doc(google(STRANGER), 'publicProfiles', FRIEND), { displayName: 'X' }));
  });
});

describe('publicProfiles limits', () => {
  const put = (data) => setDoc(doc(google(FRIEND), 'publicProfiles', FRIEND), { updatedAt: serverTimestamp(), ...data });
  it('accepts normal values', async () => {
    await assertSucceeds(put({ displayName: 'F'.repeat(80), photoUrl: 'https://x.test/p.jpg', customPaymentMethods: Array.from({ length: 20 }, () => ({ name: 'a', value: 'b', type: 'c' })) }));
    await assertSucceeds(put({ displayName: null, photoUrl: null, customPaymentMethods: [] }));
  });
  it('rejects oversized or mistyped values', async () => {
    await assertFails(put({ displayName: 'F'.repeat(81) }));
    await assertFails(put({ displayName: 5 }));
    await assertFails(put({ photoUrl: 'http://x.test/p.jpg' }));
    await assertFails(put({ photoUrl: 'https://x.test/' + 'a'.repeat(500) }));
    await assertFails(put({ photoUrl: 7 }));
    await assertFails(put({ customPaymentMethods: Array.from({ length: 21 }, () => ({ name: 'a' })) }));
    await assertFails(put({ customPaymentMethods: 'cash' }));
  });
});

describe('phoneClaims', () => {
  it('requires an E.164 document id', async () => {
    const claim = (phone) => setDoc(doc(google(FRIEND), 'phoneClaims', phone), { uid: FRIEND, createdAt: serverTimestamp() });
    await assertSucceeds(claim('+14155550123'));
    await assertFails(claim('01000000002'));
    await assertFails(claim('+0123456789'));
    await assertFails(claim('+12345'));
    await assertFails(claim('+1234567890123456'));
    await assertFails(claim('+1415555abcd'));
    await assertFails(claim('+1 415 555 0123'));
  });

  it('lets a user claim a free number for themselves only', async () => {
    await assertSucceeds(setDoc(doc(google(FRIEND), 'phoneClaims', '+201000000002'), { uid: FRIEND, createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(google(FRIEND), 'phoneClaims', '+201000000003'), { uid: STRANGER }));
  });

  it('cannot take over an existing claim', async () => {
    await assertFails(setDoc(doc(google(STRANGER), 'phoneClaims', '+201000000001'), { uid: STRANGER }));
  });

  it('can be read by full users but not guests', async () => {
    await assertSucceeds(getDoc(doc(google(STRANGER), 'phoneClaims', '+201000000001')));
    await assertFails(getDoc(doc(guest(), 'phoneClaims', '+201000000001')));
  });
});

describe('notifications', () => {
  const note = (extra = {}) => ({ title: 'Paid', body: 'Friend paid', date: serverTimestamp(), read: false, data: { billId: 'b1' }, ...extra });
  const col = (db, uid, id) => doc(db, 'users', uid, 'notifications', id);

  it('lets a guest notify the bill host, and members notify each other', async () => {
    await assertSucceeds(setDoc(col(guest(), HOST, 'n1'), note()));
    await assertSucceeds(setDoc(col(google(FRIEND), HOST, 'n1b'), note()));
    await assertSucceeds(setDoc(col(google(HOST), FRIEND, 'n1c'), note()));
    await assertSucceeds(setDoc(col(google(HOST), FRIEND, 'n1d'), note({ titleKey: 'k', bodyKey: 'k2', titleArgs: { a: 'b' }, bodyArgs: { a: 'b' } })));
  });

  it('rejects unauthenticated or malformed notifications', async () => {
    await assertFails(setDoc(col(anon(), HOST, 'n2'), note()));
    await assertFails(setDoc(col(guest(), HOST, 'n3'), note({ read: true })));
    await assertFails(setDoc(col(guest(), HOST, 'n4'), note({ title: 'x'.repeat(201) })));
    await assertFails(setDoc(col(guest(), HOST, 'n4b'), note({ body: 'x'.repeat(1001) })));
  });

  it('rejects notifications without a shared bill', async () => {
    await assertFails(setDoc(col(google(STRANGER), HOST, 'n5'), note()));
    await assertFails(setDoc(col(google(FRIEND), HOST, 'n6'), note({ data: null })));
    await assertFails(setDoc(col(google(FRIEND), HOST, 'n7'), note({ data: { type: 'x' } })));
    await assertFails(setDoc(col(google(FRIEND), HOST, 'n8'), note({ data: { billId: 'missing' } })));
    await assertFails(setDoc(col(google(FRIEND), HOST, 'n9'), note({ data: { billId: 5 } })));
    await assertFails(setDoc(col(google(FRIEND), HOST, 'n9b'), (() => { const { data, ...rest } = note(); return rest; })()));
  });

  it('rejects notifying someone who is not on the bill', async () => {
    await assertFails(setDoc(col(google(HOST), STRANGER, 'n10'), note()));
    await assertFails(setDoc(col(google(FRIEND), STRANGER, 'n11'), note()));
  });

  it('guests may only notify the host, never members', async () => {
    await assertFails(setDoc(col(guest(), FRIEND, 'n12'), note()));
    await assertFails(setDoc(col(guest(), STRANGER, 'n13'), note()));
  });

  it('caps the data map and key/arg sizes', async () => {
    const big = Object.fromEntries(Array.from({ length: 25 }, (_, i) => [`k${i}`, 'v']));
    await assertFails(setDoc(col(google(FRIEND), HOST, 'n14'), note({ data: { billId: 'b1', ...big } })));
    await assertFails(setDoc(col(google(FRIEND), HOST, 'n15'), note({ bodyArgs: big })));
    await assertFails(setDoc(col(google(FRIEND), HOST, 'n16'), note({ titleKey: 'x'.repeat(101) })));
  });

  it('admins may notify anyone without a bill (admin_message)', async () => {
    await assertSucceeds(setDoc(col(google(ADMIN), STRANGER, 'n17'), note({ data: { type: 'admin_message' } })));
    await assertSucceeds(setDoc(col(google(ADMIN), STRANGER, 'n18'), note({ data: null })));
  });

  it('suspended users cannot notify', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'bills', 'bs'), { ...bill, participants_uids: [HOST, 'suspended-uid'] });
    });
    await assertFails(setDoc(col(google('suspended-uid'), HOST, 'n19'), note({ data: { billId: 'bs' } })));
  });

  it('only the owner reads their notifications', async () => {
    await assertFails(getDocs(collection(google(STRANGER), 'users', HOST, 'notifications')));
    await assertSucceeds(getDocs(collection(google(HOST), 'users', HOST, 'notifications')));
  });
});

describe('groups (2.0 ledgers)', () => {
  const newGroup = (extra = {}) => ({
    name: 'Flat 4B', createdBy: FRIEND, createdAt: serverTimestamp(), members: [], memberIds: [FRIEND, HOST],
    type: 'home', currency: 'EGP', budgetMinor: null, simplifyDebts: true, ...extra,
  });

  it('accepts the legacy 1.x shape and the new ledger fields', async () => {
    await assertSucceeds(setDoc(doc(google(FRIEND), 'groups', 'n1'), { name: 'Old style', createdBy: FRIEND, createdAt: serverTimestamp(), members: [], memberIds: [FRIEND] }));
    await assertSucceeds(setDoc(doc(google(FRIEND), 'groups', 'n2'), newGroup({ startDate: Timestamp.now(), endDate: Timestamp.now(), budgetMinor: 5000 })));
  });

  it('rejects bad types, currencies and budgets', async () => {
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'n3'), newGroup({ type: 'party' })));
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'n4'), newGroup({ currency: 'usd' })));
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'n5'), newGroup({ budgetMinor: 12.5 })));
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'n6'), newGroup({ budgetMinor: -1 })));
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'n7'), newGroup({ secret: true })));
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'n8'), newGroup({ memberIds: [HOST] })));
    await assertFails(setDoc(doc(guest(), 'groups', 'n9'), newGroup({ createdBy: GUEST, memberIds: [GUEST] })));
  });

  it('only members read a group', async () => {
    await assertSucceeds(getDoc(doc(google(FRIEND), 'groups', 'g1')));
    await assertFails(getDoc(doc(google(STRANGER), 'groups', 'g1')));
    await assertFails(getDocs(query(collection(google(STRANGER), 'groups'), where('memberIds', 'array-contains', HOST))));
  });

  it('members list their own groups (the home screen query)', async () => {
    await assertSucceeds(getDocs(query(collection(google(FRIEND), 'groups'), where('memberIds', 'array-contains', FRIEND))));
    await assertSucceeds(getDocs(query(collection(google(HOST), 'groups'), where('memberIds', 'array-contains', HOST))));
  });

  it('members list a group\'s bills and payments', async () => {
    await assertSucceeds(getDocs(query(collection(google(FRIEND), 'bills'), where('groupId', '==', 'g1'), orderBy('date', 'desc'), limit(50))));
    await assertSucceeds(getDocs(query(collection(google(FRIEND), 'groups', 'g1', 'payments'), orderBy('createdAt', 'desc'), limit(50))));
  });

  it('members change ledger settings; only the owner changes name or members', async () => {
    await assertSucceeds(updateDoc(doc(google(FRIEND), 'groups', 'g1'), { budgetMinor: 90000, archived: true, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(google(FRIEND), 'groups', 'g1'), { name: 'Mine now' }));
    await assertFails(updateDoc(doc(google(FRIEND), 'groups', 'g1'), { memberIds: [FRIEND, HOST, STRANGER] }));
    await assertSucceeds(updateDoc(doc(google(HOST), 'groups', 'g1'), { name: 'Dahab', memberIds: [HOST, FRIEND, STRANGER] }));
    await assertFails(updateDoc(doc(google(STRANGER), 'groups', 'legacy'), { archived: true }));
    await assertFails(updateDoc(doc(google(HOST), 'groups', 'g1'), { type: 'castle' }));
  });
});

describe('group bills', () => {
  it('members list every bill in their group, strangers cannot', async () => {
    const q = (db) => query(collection(db, 'bills'), where('groupId', '==', 'g1'), orderBy('date', 'desc'), limit(50));
    await assertSucceeds(getDocs(q(google(FRIEND))));
    await assertFails(getDocs(q(google(STRANGER))));
  });

  it('a bill can only be filed into a group the host belongs to', async () => {
    await assertSucceeds(setDoc(doc(google(HOST), 'bills', 'nb1'), { ...bill, groupId: 'g1', totalMinor: 1000 }));
    await assertFails(setDoc(doc(google(HOST), 'bills', 'nb2'), { ...bill, hostId: HOST, groupId: 'not-mine' }));
    await assertFails(setDoc(doc(google(HOST), 'bills', 'nb3'), { ...bill, totalMinor: 10.5 }));
    await assertFails(updateDoc(doc(google(HOST), 'bills', 'b1'), { groupId: 'missing' }));
    await assertSucceeds(updateDoc(doc(google(HOST), 'bills', 'b1'), { groupId: 'g1' }));
    await assertSucceeds(updateDoc(doc(google(HOST), 'bills', 'gb1'), { storeName: 'Renamed' }));
  });
});

describe('group payments', () => {
  const payment = (extra = {}) => ({
    kind: 'payment', from: FRIEND, to: HOST, amountMinor: 4100, currency: 'USD', method: 'paypal',
    groupId: 'g1', participants_uids: [FRIEND, HOST], createdBy: FRIEND, createdAt: serverTimestamp(), ...extra,
  });

  it('a member records a payment they are a side of', async () => {
    await assertSucceeds(setDoc(doc(google(FRIEND), 'groups', 'g1', 'payments', 'x1'), payment()));
    // Recording cash a guest member handed you.
    await assertSucceeds(setDoc(doc(google(HOST), 'groups', 'g1', 'payments', 'x2'),
      payment({ from: 'guest-member', to: HOST, participants_uids: ['guest-member', HOST], createdBy: HOST, method: 'cash' })));
  });

  it('the host records a marked-paid share as a payment from the member', async () => {
    await assertSucceeds(setDoc(doc(google(HOST), 'groups', 'g1', 'payments', 'mp1'),
      payment({ createdBy: HOST, method: 'marked_paid', billId: 'gb1', fromName: 'Friend' })));
    await assertFails(setDoc(doc(google(STRANGER), 'groups', 'g1', 'payments', 'mp2'),
      payment({ createdBy: STRANGER, method: 'marked_paid', billId: 'gb1' })));
  });

  it('validates amount, sides and shape', async () => {
    const col = (db, id) => doc(db, 'groups', 'g1', 'payments', id);
    await assertFails(setDoc(col(google(FRIEND), 'y1'), payment({ amountMinor: 0 })));
    await assertFails(setDoc(col(google(FRIEND), 'y2'), payment({ amountMinor: -5 })));
    await assertFails(setDoc(col(google(FRIEND), 'y3'), payment({ amountMinor: 41.5 })));
    await assertFails(setDoc(col(google(FRIEND), 'y4'), payment({ amountMinor: '4100' })));
    await assertFails(setDoc(col(google(FRIEND), 'y5'), payment({ from: HOST, to: 'guest-member', participants_uids: [HOST, 'guest-member'] })));
    await assertFails(setDoc(col(google(FRIEND), 'y6'), payment({ to: STRANGER, participants_uids: [FRIEND, STRANGER] })));
    await assertFails(setDoc(col(google(FRIEND), 'y7'), payment({ participants_uids: [FRIEND, HOST, STRANGER] })));
    await assertFails(setDoc(col(google(FRIEND), 'y8'), payment({ createdBy: HOST })));
    await assertFails(setDoc(col(google(FRIEND), 'y9'), payment({ extra: 1 })));
    await assertFails(setDoc(col(google(FRIEND), 'y10'), payment({ kind: 'iou' })));
    await assertFails(setDoc(col(google(FRIEND), 'y11'), payment({ from: FRIEND, to: FRIEND })));
    await assertFails(setDoc(col(google(FRIEND), 'y12'), payment({ createdAt: Timestamp.fromMillis(0) })));
    await assertFails(setDoc(col(google(FRIEND), 'y13'), payment({ groupId: 'other' })));
    await assertFails(setDoc(col(google(STRANGER), 'y14'), payment({ from: STRANGER, participants_uids: [STRANGER, HOST], createdBy: STRANGER })));
    await assertFails(setDoc(col(guest(), 'y15'), payment({ from: GUEST, participants_uids: [GUEST, HOST], createdBy: GUEST })));
  });

  it('only members read group payments', async () => {
    await assertSucceeds(getDocs(collection(google(HOST), 'groups', 'g1', 'payments')));
    await assertFails(getDocs(collection(google(STRANGER), 'groups', 'g1', 'payments')));
    await assertFails(getDoc(doc(google(STRANGER), 'groups', 'g1', 'payments', 'gp1')));
  });

  it('payments are immutable except proof and note by the creator', async () => {
    const ref = (db) => doc(db, 'groups', 'g1', 'payments', 'gp1');
    await assertSucceeds(updateDoc(ref(google(FRIEND)), { proofUrl: 'https://x/proof.jpg' }));
    await assertFails(updateDoc(ref(google(FRIEND)), { amountMinor: 1 }));
    await assertFails(updateDoc(ref(google(HOST)), { proofUrl: 'https://x/other.jpg' }));
    await assertSucceeds(updateDoc(ref(google(ADMIN)), { amountMinor: 1 }));
  });

  it('the creator can delete within 24 hours, others cannot', async () => {
    await assertFails(deleteDoc(doc(google(HOST), 'groups', 'g1', 'payments', 'gp1')));
    await assertSucceeds(deleteDoc(doc(google(FRIEND), 'groups', 'g1', 'payments', 'gp1')));
  });
});

describe('friend payments and Quick IOUs', () => {
  const iou = (extra = {}) => ({
    kind: 'iou', from: FRIEND, to: HOST, amountMinor: 2000, currency: 'EGP', method: 'iou', note: 'coffee',
    participants_uids: [FRIEND, HOST], createdBy: HOST, createdAt: serverTimestamp(), ...extra,
  });

  it('either side can create one with a valid shape', async () => {
    await assertSucceeds(setDoc(doc(google(HOST), 'payments', 'i1'), iou()));
    await assertSucceeds(setDoc(doc(google(FRIEND), 'payments', 'i2'), iou({ kind: 'payment', createdBy: FRIEND, method: 'instapay' })));
  });

  it('rejects third parties, bad amounts, extra viewers and group ids', async () => {
    await assertFails(setDoc(doc(google(STRANGER), 'payments', 'i3'), iou({ createdBy: STRANGER })));
    await assertFails(setDoc(doc(google(HOST), 'payments', 'i4'), iou({ amountMinor: 0 })));
    await assertFails(setDoc(doc(google(HOST), 'payments', 'i5'), iou({ amountMinor: 20.5 })));
    await assertFails(setDoc(doc(google(HOST), 'payments', 'i6'), iou({ participants_uids: [FRIEND, HOST, STRANGER] })));
    await assertFails(setDoc(doc(google(HOST), 'payments', 'i7'), iou({ groupId: 'g1' })));
    await assertFails(setDoc(doc(google(HOST), 'payments', 'i8'), iou({ note: 'x'.repeat(201) })));
    await assertFails(setDoc(doc(anon(), 'payments', 'i9'), iou()));
  });

  it('only the two sides read them, and listing is scoped to yourself', async () => {
    await assertSucceeds(getDoc(doc(google(FRIEND), 'payments', 'p1')));
    await assertFails(getDoc(doc(google(STRANGER), 'payments', 'p1')));
    await assertSucceeds(getDocs(query(collection(google(FRIEND), 'payments'), where('participants_uids', 'array-contains', FRIEND), orderBy('createdAt', 'desc'))));
    await assertFails(getDocs(collection(google(STRANGER), 'payments')));
    await assertFails(getDocs(query(collection(google(STRANGER), 'payments'), where('participants_uids', 'array-contains', FRIEND))));
  });

  it('cannot be edited, and deletes close after 24 hours', async () => {
    await assertFails(updateDoc(doc(google(HOST), 'payments', 'p1'), { amountMinor: 1 }));
    await assertFails(updateDoc(doc(google(FRIEND), 'payments', 'p1'), { note: 'not mine' }));
    await assertSucceeds(updateDoc(doc(google(HOST), 'payments', 'p1'), { note: 'coffee' }));
    await assertFails(deleteDoc(doc(google(FRIEND), 'payments', 'p1')));
    await assertFails(deleteDoc(doc(google(HOST), 'payments', 'old')));
    await assertSucceeds(deleteDoc(doc(google(HOST), 'payments', 'p1')));
    await assertSucceeds(deleteDoc(doc(google(ADMIN), 'payments', 'old')));
  });
});

describe('activity collection group', () => {
  it('lists your payments across groups and friends', async () => {
    const q = (db, uid) => query(collectionGroup(db, 'payments'), where('participants_uids', 'array-contains', uid), orderBy('createdAt', 'desc'), limit(20));
    const snap = await assertSucceeds(getDocs(q(google(FRIEND), FRIEND)));
    if (snap.size !== 3) throw new Error(`expected 3 payments, got ${snap.size}`);
    await assertFails(getDocs(q(google(STRANGER), FRIEND)));
    await assertFails(getDocs(query(collectionGroup(google(STRANGER), 'payments'))));
  });
});

describe('default deny', () => {
  it('denies unknown collections', async () => {
    await assertFails(getDoc(doc(google(HOST), 'secrets', 'x')));
  });
});

describe('suspension', () => {
  const S = 'suspended-uid';
  it('suspended users cannot create bills, groups, payments or profiles', async () => {
    await assertFails(setDoc(doc(google(S), 'bills', 'sb1'), { ...bill, hostId: S, participants_uids: [S] }));
    await assertFails(setDoc(doc(google(S), 'groups', 'sg1'), { name: 'X', createdBy: S, createdAt: serverTimestamp(), members: [], memberIds: [S] }));
    await assertFails(setDoc(doc(google(S), 'publicProfiles', S), { displayName: 'Banned' }));
    await assertFails(setDoc(doc(google(S), 'phoneClaims', '+201000000099'), { uid: S, createdAt: serverTimestamp() }));
  });
  it('active users still can', async () => {
    await assertSucceeds(setDoc(doc(google(FRIEND), 'groups', 'fg1'), { name: 'Y', createdBy: FRIEND, createdAt: serverTimestamp(), members: [], memberIds: [FRIEND] }));
  });
  it('users cannot suspend or unsuspend themselves, admins can', async () => {
    await assertFails(updateDoc(doc(google(S), 'users', S), { suspended: false }));
    await assertFails(updateDoc(doc(google(FRIEND), 'users', FRIEND), { suspended: true }));
    await assertSucceeds(updateDoc(doc(google(ADMIN), 'users', FRIEND), { suspended: true, suspendedBy: ADMIN, suspendedAt: serverTimestamp() }));
  });
});

describe('recurring bill templates', () => {
  const t = (extra = {}) => ({
    name: 'Rent', amountMinor: 1260000, currency: 'EGP', frequency: 'monthly', anchorDay: 1,
    nextOn: Timestamp.now(), active: true, createdBy: FRIEND, createdAt: serverTimestamp(), memberIds: [HOST, FRIEND], ...extra,
  });
  it('members create, strangers and bad shapes fail', async () => {
    await assertSucceeds(setDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r1'), t()));
    await assertFails(setDoc(doc(google(STRANGER), 'groups', 'g1', 'recurring', 'r2'), t({ createdBy: STRANGER })));
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r3'), t({ amountMinor: 0 })));
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r4'), t({ frequency: 'daily' })));
    await assertFails(setDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r5'), t({ createdBy: HOST })));
  });
  it('validates template field types and ranges', async () => {
    const c = (id, extra) => setDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', id), t(extra));
    await assertFails(c('v1', { amountMinor: 1000000001 }));
    await assertSucceeds(c('v2', { amountMinor: 1000000000 }));
    await assertFails(c('v3', { currency: 'egp' }));
    await assertFails(c('v4', { currency: 'EG' }));
    await assertFails(c('v5', { currency: 'EGPP' }));
    await assertFails(c('v6', { nextOn: 'tomorrow' }));
    await assertFails(c('v7', { anchorDay: 0 }));
    await assertFails(c('v8', { anchorDay: 32 }));
    await assertFails(c('v9', { anchorDay: 1.5 }));
    await assertFails(c('v10', { active: 'yes' }));
    await assertFails(c('v11', { amountMinor: 10.5 }));
  });
  it('memberIds may only name current group members', async () => {
    const c = (id, extra) => setDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', id), t(extra));
    await assertFails(c('m1', { memberIds: [HOST, STRANGER] }));
    await assertSucceeds(c('m2', { memberIds: [HOST, 'guest-member'] }));
    await assertFails(c('m3', { memberIds: 'all' }));
  });
  it('a member who left the group cannot edit their template', async () => {
    await assertSucceeds(setDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r1'), t()));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'groups', 'g1'), { name: 'Dahab trip', createdBy: HOST, members: [], memberIds: [HOST] });
    });
    await assertFails(updateDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r1'), { active: false }));
  });
  it('only the creator updates, the owner can delete', async () => {
    await assertSucceeds(setDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r1'), t()));
    await assertSucceeds(updateDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r1'), { active: false }));
    await assertFails(updateDoc(doc(google(HOST), 'groups', 'g1', 'recurring', 'r1'), { active: true }));
    await assertFails(updateDoc(doc(google(FRIEND), 'groups', 'g1', 'recurring', 'r1'), { createdBy: HOST }));
    await assertSucceeds(deleteDoc(doc(google(HOST), 'groups', 'g1', 'recurring', 'r1')));
  });
});

describe('admin audit log', () => {
  const e = (extra = {}) => ({ adminUid: ADMIN, action: 'grant_points', targetUid: FRIEND, at: serverTimestamp(), details: { points: 10 }, ...extra });
  it('admins append, others cannot', async () => {
    await assertSucceeds(setDoc(doc(google(ADMIN), 'adminAudit', 'a1'), e()));
    await assertFails(setDoc(doc(google(FRIEND), 'adminAudit', 'a2'), e({ adminUid: FRIEND })));
    await assertFails(setDoc(doc(google(ADMIN), 'adminAudit', 'a3'), e({ adminUid: HOST })));
    await assertFails(setDoc(doc(google(ADMIN), 'adminAudit', 'a4'), e({ at: Timestamp.fromMillis(0) })));
  });
  it('entries are read-only for everyone and readable only by admins', async () => {
    await assertSucceeds(setDoc(doc(google(ADMIN), 'adminAudit', 'a1'), e()));
    await assertFails(updateDoc(doc(google(ADMIN), 'adminAudit', 'a1'), { action: 'x' }));
    await assertFails(deleteDoc(doc(google(ADMIN), 'adminAudit', 'a1')));
    await assertFails(getDoc(doc(google(FRIEND), 'adminAudit', 'a1')));
    await assertSucceeds(getDoc(doc(google(ADMIN), 'adminAudit', 'a1')));
  });
});

describe('account tombstones (delete + recreate)', () => {
  const T = 'tomb-uid';

  const seedUser = (uid, data) => env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), data);
  });

  // Mirrors the app's account deletion batch.
  const deleteAccount = async (uid, { tombstone = true } = {}) => {
    const db = google(uid);
    const batch = writeBatch(db);
    batch.delete(doc(db, 'users', uid));
    if (tombstone) batch.set(doc(db, 'accountTombstones', uid), { deletedAt: serverTimestamp() });
    return batch.commit();
  };

  it('a suspended owner can only delete together with the tombstone', async () => {
    await seedUser(T, { displayName: 'T', suspended: true });
    await assertFails(deleteDoc(doc(google(T), 'users', T)));
    await assertFails(deleteAccount(T, { tombstone: false }));
    await assertSucceeds(deleteAccount(T));
  });

  // Stage A: the 1.2.0 app (in the stores) deletes without a tombstone.
  it('1.2.0 account deletion batch still works', async () => {
    const U = 'old-app-uid';
    await seedUser(U, { displayName: 'U', points: 3 });
    await env.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await setDoc(doc(f, 'bills', 'ob1'), { ...bill, hostId: U, participants_uids: [U] });
      await setDoc(doc(f, 'groups', 'og1'), { name: 'G', ownerId: U, memberIds: [U, FRIEND] });
      await setDoc(doc(f, 'users', U, 'notifications', 'n1'), { title: 't', body: 'b', read: false });
    });
    const db = google(U);
    const hostBills = await assertSucceeds(getDocs(query(collection(db, 'bills'), where('hostId', '==', U))));
    const groups = await assertSucceeds(getDocs(query(collection(db, 'groups'), where('ownerId', '==', U))));
    const notes = await assertSucceeds(getDocs(collection(db, 'users', U, 'notifications')));
    const batch = writeBatch(db);
    for (const d of [...hostBills.docs, ...groups.docs, ...notes.docs]) batch.delete(d.ref);
    batch.delete(doc(db, 'users', U));
    await assertSucceeds(batch.commit());
  });

  it('strangers cannot list groups by someone else\'s ownerId', async () => {
    await assertFails(getDocs(query(collection(google(STRANGER), 'groups'), where('ownerId', '==', HOST))));
  });

  it('exploit: delete + recreate cannot reset points', async () => {
    await seedUser(T, { displayName: 'T', points: 0 });
    await assertSucceeds(deleteAccount(T));
    await assertFails(setDoc(doc(google(T), 'users', T), { displayName: 'T', points: 7 }));
    await assertFails(setDoc(doc(google(T), 'users', T), { displayName: 'T' }));
    await assertFails(setDoc(doc(google(T), 'users', T), { points: 7 }, { merge: true }));
  });

  it('exploit: delete + recreate cannot wash out a suspension', async () => {
    await seedUser(T, { displayName: 'T', suspended: true });
    await assertSucceeds(deleteAccount(T));
    // Missing doc + tombstone is treated as suspended.
    await assertFails(setDoc(doc(google(T), 'bills', 'tb1'), { ...bill, hostId: T, participants_uids: [T] }));
    await assertFails(setDoc(doc(google(T), 'groups', 'tg1'), { name: 'X', createdBy: T, createdAt: serverTimestamp(), members: [], memberIds: [T] }));
    await assertFails(setDoc(doc(google(T), 'users', T), { displayName: 'T' }));
  });

  it('a user who never deleted their doc but has none yet is still active', async () => {
    await assertSucceeds(setDoc(doc(google('brand-new'), 'groups', 'bn1'), { name: 'X', createdBy: 'brand-new', createdAt: serverTimestamp(), members: [], memberIds: ['brand-new'] }));
    await assertSucceeds(setDoc(doc(google('brand-new2'), 'users', 'brand-new2'), { points: 7 }));
  });

  it('the welcome grant on update is blocked once a tombstone exists', async () => {
    await seedUser('late-uid', { fcmToken: 'x' });
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'accountTombstones', 'late-uid'), { deletedAt: Timestamp.now() });
    });
    await assertFails(setDoc(doc(google('late-uid'), 'users', 'late-uid'), { points: 7 }, { merge: true }));
  });

  it('tombstone shape: owner creates once with server time, nobody else', async () => {
    await assertFails(setDoc(doc(google(T), 'accountTombstones', T), { deletedAt: Timestamp.fromMillis(0) }));
    await assertFails(setDoc(doc(google(T), 'accountTombstones', T), { deletedAt: serverTimestamp(), extra: 1 }));
    await assertFails(setDoc(doc(google(STRANGER), 'accountTombstones', T), { deletedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(guest(), 'accountTombstones', GUEST), { deletedAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(google(T), 'accountTombstones', T), { deletedAt: serverTimestamp() }));
  });

  it('tombstones are immutable for users, readable by owner and admin only', async () => {
    await assertSucceeds(setDoc(doc(google(T), 'accountTombstones', T), { deletedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(google(T), 'accountTombstones', T), { deletedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(google(T), 'accountTombstones', T), { deletedAt: Timestamp.now() }));
    await assertFails(deleteDoc(doc(google(T), 'accountTombstones', T)));
    await assertSucceeds(getDoc(doc(google(T), 'accountTombstones', T)));
    await assertSucceeds(getDoc(doc(google(ADMIN), 'accountTombstones', T)));
    await assertFails(getDoc(doc(google(STRANGER), 'accountTombstones', T)));
    await assertSucceeds(deleteDoc(doc(google(ADMIN), 'accountTombstones', T)));
  });

  it('admins can still delete any user doc and clear a tombstone', async () => {
    await assertSucceeds(deleteDoc(doc(google(ADMIN), 'users', HOST)));
  });

  it('a retry after a half-finished deletion works without rewriting the tombstone', async () => {
    await seedUser(T, { displayName: 'T' });
    await assertSucceeds(deleteAccount(T));
    const db = google(T);
    const batch = writeBatch(db);
    batch.delete(doc(db, 'users', T));
    await assertSucceeds(batch.commit());
  });
});
