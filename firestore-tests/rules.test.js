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
    { name: 'Host', uid: HOST, status: 'PAID' },
    { name: 'Friend', uid: FRIEND, status: 'PENDING' },
    { name: 'Walk-in', status: 'PENDING' },
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

  it('stage A: signed-in users can still get a user by id', async () => {
    await assertSucceeds(getDoc(doc(google(FRIEND), 'users', HOST)));
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

  it('allows a guest to update payment state only', async () => {
    const participants = bill.participants.map((p, i) => (i === 2 ? { ...p, status: 'REVIEW' } : p));
    await assertSucceeds(updateDoc(doc(guest(), 'bills', 'b1'), { participants }));
  });

  it('denies guests adding or removing participants or changing other fields', async () => {
    await assertFails(updateDoc(doc(guest(), 'bills', 'b1'), { participants: bill.participants.slice(0, 2) }));
    await assertFails(updateDoc(doc(guest(), 'bills', 'b1'), { storeName: 'Hacked' }));
    await assertFails(updateDoc(doc(guest(), 'bills', 'b1'), { participants_uids: [GUEST] }));
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

describe('phoneClaims', () => {
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
  const note = () => ({ title: 'Paid', body: 'Friend paid', date: serverTimestamp(), read: false, data: { billId: 'b1' } });

  it('lets signed-in users and guests write a well-formed notification', async () => {
    await assertSucceeds(setDoc(doc(guest(), 'users', HOST, 'notifications', 'n1'), note()));
  });

  it('rejects unauthenticated or malformed notifications', async () => {
    await assertFails(setDoc(doc(anon(), 'users', HOST, 'notifications', 'n2'), note()));
    await assertFails(setDoc(doc(guest(), 'users', HOST, 'notifications', 'n3'), { ...note(), read: true }));
    await assertFails(setDoc(doc(guest(), 'users', HOST, 'notifications', 'n4'), { ...note(), title: 'x'.repeat(201) }));
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
