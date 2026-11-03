// Firestore rules tests. Run with `npm test` (starts the emulator).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
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
    await setDoc(doc(db, 'users', 'fresh-uid'), { fcmToken: 'x' });
    await setDoc(doc(db, 'bills', 'b1'), bill);
    await setDoc(doc(db, 'publicProfiles', HOST), { displayName: 'Host', customPaymentMethods: [] });
    await setDoc(doc(db, 'phoneClaims', '+201000000001'), { uid: HOST });
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

describe('default deny', () => {
  it('denies unknown collections', async () => {
    await assertFails(getDoc(doc(google(HOST), 'secrets', 'x')));
  });
});
