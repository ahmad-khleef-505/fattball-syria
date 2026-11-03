import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {config} from "dotenv";
import {resolve} from "node:path";

config({path: resolve(__dirname, "..", "..", ".env.seed")});

const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
const firstPassword = process.env.SEED_ADMIN_1_PASSWORD;
const secondPassword = process.env.SEED_ADMIN_2_PASSWORD;

if (!projectId) {
  throw new Error("FIREBASE_PROJECT_ID is required in .env.seed.");
}
if (!firstPassword || !secondPassword) {
  throw new Error(
    "SEED_ADMIN_1_PASSWORD and SEED_ADMIN_2_PASSWORD are required in .env.seed.",
  );
}
if (firstPassword.length < 12 || secondPassword.length < 12) {
  throw new Error("Each seed password must contain at least 12 characters.");
}
if (firstPassword === secondPassword) {
  throw new Error("Use different passwords for the two super admins.");
}

initializeApp({
  credential: applicationDefault(),
  projectId,
});

const auth = getAuth();
const db = getFirestore();

const admins = [
  {
    displayName: "محمد نور",
    email: "nurm41143@gmail.com",
    password: firstPassword,
  },
  {
    displayName: "أحمد الخليف",
    email: "ahmadkhleefahmad@gmail.com",
    password: secondPassword,
  },
] as const;

async function seedAdmin(admin: (typeof admins)[number]): Promise<void> {
  const normalizedEmail = admin.email.toLowerCase();
  let user;

  try {
    user = await auth.getUserByEmail(normalizedEmail);
    user = await auth.updateUser(user.uid, {
      displayName: admin.displayName,
      password: admin.password,
      disabled: false,
    });
  } catch (error) {
    const code = (error as {code?: unknown}).code;
    if (code !== "auth/user-not-found") throw error;
    user = await auth.createUser({
      displayName: admin.displayName,
      email: normalizedEmail,
      emailVerified: false,
      password: admin.password,
      disabled: false,
    });
  }

  const customClaims = {
    ...(user.customClaims ?? {}),
    admin: true,
    superadmin: true,
  };
  await auth.setCustomUserClaims(user.uid, customClaims);

  await db.collection("users").doc(user.uid).set(
    {
      name: admin.displayName,
      email: normalizedEmail,
      role: "superadmin",
      phone: null,
      createdAt: Timestamp.now(),
      isActive: true,
      subscriptionExpiry: null,
      fcmToken: null,
    },
    {merge: true},
  );

  console.log(`Seeded super admin: ${admin.displayName} (${normalizedEmail})`);
}

async function main(): Promise<void> {
  for (const admin of admins) await seedAdmin(admin);
  console.log(
    "Admin seeding completed. Sign in and change both passwords immediately.",
  );
}

main().catch((error: unknown) => {
  console.error("Failed to seed super admins.", error);
  process.exitCode = 1;
});
