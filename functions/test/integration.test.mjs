import assert from "node:assert/strict";
import {after, before, test} from "node:test";
import {
  deleteApp,
  initializeApp as initializeClientApp,
} from "firebase/app";
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
} from "firebase/auth";
import {
  collection,
  connectFirestoreEmulator,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from "firebase/functions";
import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from "firebase-admin/app";
import {getAuth as getAdminAuth} from "firebase-admin/auth";
import {
  getFirestore as getAdminFirestore,
  Timestamp as AdminTimestamp,
} from "firebase-admin/firestore";

const projectId = process.env.GCLOUD_PROJECT ?? "demo-integration";
const runId = `${Date.now()}-${process.pid}`;
const clients = [];
let adminApp;
let admin;
let adminFirestore;
let owner;
let customer;
let superAdmin;
let fieldId;
let coachId;

function requiredPort(key, fallback) {
  const value = process.env[key];
  if (!value) return fallback;
  const parsed = Number(value.split(":").at(-1));
  assert.ok(Number.isInteger(parsed) && parsed > 0, `${key} must include a port`);
  return parsed;
}

async function createClient(role) {
  const app = initializeClientApp(
    {
      apiKey: "integration-test-api-key",
      appId: `1:123456789:web:${role}`,
      projectId,
    },
    `integration-${runId}-${role}`,
  );
  clients.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(
    auth,
    `http://127.0.0.1:${requiredPort("FIREBASE_AUTH_EMULATOR_HOST", 29099)}`,
    {disableWarnings: true},
  );
  const firestore = getFirestore(app);
  connectFirestoreEmulator(
    firestore,
    "127.0.0.1",
    requiredPort("FIRESTORE_EMULATOR_HOST", 28082),
  );
  const functions = getFunctions(app, "me-central1");
  connectFunctionsEmulator(
    functions,
    "127.0.0.1",
    requiredPort("FUNCTIONS_EMULATOR_HOST", 25001),
  );

  const credential = await createUserWithEmailAndPassword(
    auth,
    `${role}-${runId}@integration.example`,
    "IntegrationPassword!2026",
  );
  return {app, auth, firestore, functions, user: credential.user};
}

function damascusDayKey(date) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Damascus",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const value = (type) => parts.find((part) => part.type === type)?.value;
  return `${value("year")}${value("month")}${value("day")}`;
}

function futureSlot(daysAhead) {
  const startAt = new Date(Date.now() + daysAhead * 24 * 60 * 60 * 1000);
  startAt.setUTCHours(13, 0, 0, 0);
  return {
    startAt,
    endAt: new Date(startAt.getTime() + 60 * 60 * 1000),
  };
}

async function assertPermissionDenied(operation) {
  await assert.rejects(operation, (error) =>
    error?.code === "permission-denied" ||
    error?.code === "functions/permission-denied"
  );
}

async function assertCallableError(operation, expectedCode) {
  await assert.rejects(operation, (error) =>
    error?.code === `functions/${expectedCode}` ||
    error?.code === expectedCode
  );
}

async function writeClientTrainingBooking({
  bookingId,
  slot,
  pricePerHour,
  trainingPricePerHour,
}) {
  const subtotalPrice = pricePerHour + trainingPricePerHour;
  const booking = {
    fieldId,
    ownerId: owner.user.uid,
    customerId: customer.user.uid,
    customerName: "ولي الأمر",
    startAt: Timestamp.fromDate(slot.startAt),
    endAt: Timestamp.fromDate(slot.endAt),
    status: "pending",
    totalPrice: subtotalPrice,
    createdAt: serverTimestamp(),
    subtotalPrice,
    promoCode: null,
    discountPercent: 0,
    depositRequired: false,
    depositAmount: 0,
    depositMethod: null,
    depositReceiptUrl: null,
    depositStatus: "not_required",
    coachId,
    coachName: "مدرب الناشئين",
    trainingChildName: "الطفل",
    trainingChildAge: 10,
    coachPricePerHour: trainingPricePerHour,
  };
  const lockId = `${fieldId}_${damascusDayKey(slot.startAt)}`;
  const bookingRef = doc(customer.firestore, "bookings", bookingId);
  const lockRef = doc(customer.firestore, "booking_locks", lockId);
  const batch = writeBatch(customer.firestore);
  batch.set(bookingRef, booking);
  batch.set(lockRef, {
    fieldId,
    ownerId: owner.user.uid,
    bookingId,
    reservations: {
      [bookingId]: {
        bookingId,
        startAt: booking.startAt,
        endAt: booking.endAt,
        status: "pending",
      },
    },
  });
  await batch.commit();
  return bookingRef;
}

before(async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Run this suite via firebase emulators:exec.",
  );
  adminApp = initializeAdminApp(
    {projectId},
    `integration-admin-${runId}`,
  );
  admin = getAdminAuth(adminApp);
  adminFirestore = getAdminFirestore(adminApp);
  owner = await createClient("owner");
  customer = await createClient("customer");
  superAdmin = await createClient("admin");
  fieldId = `training-field-${runId}`;
  coachId = `training-coach-${runId}`;

  const expiredAt = AdminTimestamp.fromDate(new Date(Date.now() - 60_000));
  await Promise.all([
    adminFirestore.collection("users").doc(owner.user.uid).set({
      name: "صاحب الملعب",
      role: "owner",
      isActive: true,
      subscriptionExpiry: expiredAt,
    }),
    adminFirestore.collection("users").doc(customer.user.uid).set({
      name: "ولي الأمر",
      role: "customer",
      isActive: true,
    }),
    adminFirestore.collection("users").doc(superAdmin.user.uid).set({
      name: "مدير الاختبار",
      role: "superadmin",
      isActive: true,
    }),
    adminFirestore.collection("fields").doc(fieldId).set({
      ownerId: owner.user.uid,
      name: "ملعب الاختبارات",
      pricePerHour: 30,
      isActive: false,
      ownerSubscriptionExpiry: expiredAt,
    }),
  ]);
  await admin.setCustomUserClaims(superAdmin.user.uid, {
    admin: true,
    superadmin: true,
  });
  await superAdmin.user.getIdToken(true);
});

after(async () => {
  await Promise.all(clients.map((app) => deleteApp(app)));
  if (adminApp) await deleteAdminApp(adminApp);
});

test("subscription, coach access, and child training booking workflows", async (t) => {
  await t.test("super admin reactivates an expired field subscription", async () => {
    await assertCallableError(
      httpsCallable(owner.functions, "activateOwnerSubscription")({
        ownerId: owner.user.uid,
        durationDays: 30,
      }),
      "permission-denied",
    );

    const activation = httpsCallable(
      superAdmin.functions,
      "activateOwnerSubscription",
    );
    const response = await activation({
      ownerId: owner.user.uid,
      durationDays: 30,
    });
    assert.equal(response.data.ownerId, owner.user.uid);
    assert.equal(typeof response.data.subscriptionId, "string");

    const [ownerSnapshot, fieldSnapshot, subscription, adminLog] =
      await Promise.all([
        adminFirestore.collection("users").doc(owner.user.uid).get(),
        adminFirestore.collection("fields").doc(fieldId).get(),
        adminFirestore
          .collection("subscriptions")
          .doc(response.data.subscriptionId)
          .get(),
        adminFirestore
          .collection("admin_logs")
          .where("targetUid", "==", owner.user.uid)
          .where("action", "==", "activate_subscription")
          .get(),
      ]);
    assert.equal(ownerSnapshot.data()?.isActive, true);
    assert.equal(fieldSnapshot.data()?.isActive, true);
    assert.ok(
      ownerSnapshot.data()?.subscriptionExpiry.toMillis() > Date.now(),
    );
    assert.equal(subscription.data()?.amountUsd, 30);
    assert.equal(adminLog.size, 1);
  });

  await t.test("owner can publish a coach and customers can only read active coaches", async () => {
    const coachRef = doc(
      owner.firestore,
      "fields",
      fieldId,
      "coaches",
      coachId,
    );
    await setDoc(coachRef, {
      fieldId,
      ownerId: owner.user.uid,
      name: "مدرب الناشئين",
      specialty: "تدريب الفئات العمرية",
      bio: "خبرة في تدريب الأطفال.",
      pricePerHour: 15,
      isActive: true,
      createdAt: serverTimestamp(),
    });

    const visibleCoaches = await getDocs(
      query(
        collection(customer.firestore, "fields", fieldId, "coaches"),
        where("isActive", "==", true),
      ),
    );
    assert.equal(visibleCoaches.size, 1);
    assert.equal(visibleCoaches.docs[0].data().pricePerHour, 15);

    await assertPermissionDenied(
      setDoc(
        doc(
          customer.firestore,
          "fields",
          fieldId,
          "coaches",
          `unauthorized-${runId}`,
        ),
        {
          fieldId,
          ownerId: customer.user.uid,
          name: "مدرب مزيف",
          specialty: "ناشئين",
          bio: "",
          pricePerHour: 1,
          isActive: true,
          createdAt: serverTimestamp(),
        },
      ),
    );
  });

  await t.test("Firestore rules accept a valid combined training booking and reject tampered pricing", async () => {
    const validSlot = futureSlot(3);
    const validBookingId = `training-valid-${runId}`;
    const bookingRef = await writeClientTrainingBooking({
      bookingId: validBookingId,
      slot: validSlot,
      pricePerHour: 30,
      trainingPricePerHour: 15,
    });
    const savedBooking = await getDoc(bookingRef);
    assert.equal(savedBooking.data()?.totalPrice, 45);
    assert.equal(savedBooking.data()?.trainingChildAge, 10);

    const lockId = `${fieldId}_${damascusDayKey(validSlot.startAt)}`;
    const lockRef = doc(owner.firestore, "booking_locks", lockId);
    const lockSnapshot = await getDoc(lockRef);
    const lockData = lockSnapshot.data();
    assert.ok(lockData);
    const reservation = lockData.reservations[validBookingId];
    const confirmedReservations = {
      ...lockData.reservations,
      [validBookingId]: {
        ...reservation,
        status: "confirmed",
      },
    };
    const ownerBookingRef = doc(owner.firestore, "bookings", validBookingId);
    const confirmation = writeBatch(owner.firestore);
    confirmation.update(ownerBookingRef, {status: "confirmed"});
    confirmation.set(
      lockRef,
      {
        bookingId: validBookingId,
        reservations: confirmedReservations,
      },
      {merge: true},
    );
    await confirmation.commit();
    assert.equal((await getDoc(ownerBookingRef)).data()?.status, "confirmed");

    await assertPermissionDenied(
      writeClientTrainingBooking({
        bookingId: `training-tampered-${runId}`,
        slot: futureSlot(4),
        pricePerHour: 30,
        trainingPricePerHour: 1,
      }),
    );
    assert.equal(
      (
        await adminFirestore
          .collection("bookings")
          .doc(`training-tampered-${runId}`)
          .get()
      ).exists,
      false,
    );
  });

  await t.test("callable booking prices the coach, prevents overlap, and checks coach availability", async () => {
    const bookingCallable = httpsCallable(
      customer.functions,
      "createBookingCallable",
    );
    const slot = futureSlot(5);
    const request = {
      fieldId,
      startAt: slot.startAt.toISOString(),
      endAt: slot.endAt.toISOString(),
      coachId,
      trainingChildName: "طفل التدريب",
      trainingChildAge: 9,
    };
    const response = await bookingCallable(request);
    assert.equal(response.data.subtotalPrice, 45);
    assert.equal(response.data.totalPrice, 45);
    assert.equal(response.data.coachId, coachId);
    assert.equal(response.data.trainingChildAge, 9);

    await assertCallableError(bookingCallable(request), "already-exists");

    await updateDoc(
      doc(owner.firestore, "fields", fieldId, "coaches", coachId),
      {isActive: false},
    );
    await assertPermissionDenied(
      getDoc(doc(customer.firestore, "fields", fieldId, "coaches", coachId)),
    );
    await assertCallableError(
      bookingCallable({
        ...request,
        ...(() => {
          const nextSlot = futureSlot(6);
          return {
            startAt: nextSlot.startAt.toISOString(),
            endAt: nextSlot.endAt.toISOString(),
          };
        })(),
      }),
      "failed-precondition",
    );
  });

  await t.test("expired subscriptions block coach booking and admin renewal restores it", async () => {
    const expiredAt = AdminTimestamp.fromDate(new Date(Date.now() - 60_000));
    await Promise.all([
      adminFirestore.collection("users").doc(owner.user.uid).update({
        subscriptionExpiry: expiredAt,
      }),
      adminFirestore.collection("fields").doc(fieldId).update({
        ownerSubscriptionExpiry: expiredAt,
      }),
    ]);

    const expiredCoachRef = doc(
      owner.firestore,
      "fields",
      fieldId,
      "coaches",
      `after-expiry-${runId}`,
    );
    await assertPermissionDenied(
      setDoc(expiredCoachRef, {
        fieldId,
        ownerId: owner.user.uid,
        name: "مدرب بعد انتهاء الاشتراك",
        specialty: "ناشئين",
        bio: "",
        pricePerHour: 10,
        isActive: true,
        createdAt: serverTimestamp(),
      }),
    );

    const slot = futureSlot(7);
    await assertCallableError(
      httpsCallable(customer.functions, "createBookingCallable")({
        fieldId,
        startAt: slot.startAt.toISOString(),
        endAt: slot.endAt.toISOString(),
        coachId,
        trainingChildName: "طفل التدريب",
        trainingChildAge: 9,
      }),
      "failed-precondition",
    );

    const response = await httpsCallable(
      superAdmin.functions,
      "activateOwnerSubscription",
    )({
      ownerId: owner.user.uid,
      durationDays: 30,
    });
    assert.ok(typeof response.data.expiresAt === "string");
    const renewedField = await adminFirestore
      .collection("fields")
      .doc(fieldId)
      .get();
    assert.ok(
      renewedField.data()?.ownerSubscriptionExpiry.toMillis() > Date.now(),
    );
  });
});
