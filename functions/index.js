// functions/index.js — Firebase Functions v2 (Gen 2)
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

if (!getApps().length) initializeApp();

// Helpers
function requireAuth(auth) {
  if (!auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
}
async function requireAdmin(auth) {
  requireAuth(auth);
  const { uid } = auth;
  const user = await getAuth().getUser(uid);
  const claims = user.customClaims || {};
  if (!claims.admin) {
    throw new HttpsError('permission-denied', 'No tienes permisos de administrador.');
  }
}
async function uidFromData(data) {
  if (data?.uid) return data.uid;
  if (data?.email) {
    const u = await getAuth().getUserByEmail(data.email);
    return u.uid;
  }
  throw new HttpsError('invalid-argument', 'Debes enviar { uid } o { email }.');
}
function withAdminFromRole(claims = {}, provided = {}) {
  // si llega admin explícito, respétalo. Si llega role, sincroniza admin según role.
  const out = { ...(claims || {}) };
  const hasAdminExplicit = Object.prototype.hasOwnProperty.call(provided, 'admin');
  const hasRole = Object.prototype.hasOwnProperty.call(provided, 'role');
  Object.assign(out, provided);
  if (!hasAdminExplicit && hasRole) {
    out.admin = provided.role === 'admin';
  }
  return out;
}

// ——— whoAmI ———
exports.whoAmI = onCall({ region: 'us-central1' }, async ({ auth }) => {
  requireAuth(auth);
  const user = await getAuth().getUser(auth.uid);
  return { uid: user.uid, email: user.email || null, claims: user.customClaims || {} };
});

// ——— setAdminRole ———
// Solo administradores pueden promover/degradar.
exports.setAdminRole = onCall({ region: 'us-central1' }, async ({ data, auth }) => {
  await requireAdmin(auth);

  const makeAdmin = (data && typeof data.admin === 'boolean') ? data.admin : true;
  const targetUid = await uidFromData(data);

  const target = await getAuth().getUser(targetUid);
  const existing = target.customClaims || {};
  const newClaims = { ...existing, admin: makeAdmin, role: makeAdmin ? 'admin' : (existing.role || 'viewer') };

  await getAuth().setCustomUserClaims(targetUid, newClaims);

  return { ok: true, uid: targetUid, email: target.email || null, admin: makeAdmin };
});

// ——— createUser ———
// data: { email: string, password?: string, claims?: { role?: 'viewer'|'editor'|'admin', tripId?: string, admin?: boolean, ... } }
exports.createUser = onCall({ region: 'us-central1' }, async ({ data, auth }) => {
  await requireAdmin(auth);

  const { email, password, claims } = data || {};
  if (!email) throw new HttpsError('invalid-argument', 'Debes enviar { email, password?, claims? }.');

  const userRecord = await getAuth().createUser({
    email,
    password: password || Math.random().toString(36).slice(-12),
    emailVerified: false,
    disabled: false,
  });

  if (claims && typeof claims === 'object') {
    // Si role === 'admin' añade admin:true (salvo que venga admin explícito)
    const finalClaims = withAdminFromRole({}, claims);
    await getAuth().setCustomUserClaims(userRecord.uid, finalClaims);
  }

  return {
    ok: true,
    uid: userRecord.uid,
    email: userRecord.email,
    claims: claims || {},
  };
});

// ——— updateUserClaims ———
// data: { uid?: string, email?: string, claims: object }
exports.updateUserClaims = onCall({ region: 'us-central1' }, async ({ data, auth }) => {
  await requireAdmin(auth);
  if (!data || typeof data.claims !== 'object') {
    throw new HttpsError('invalid-argument', 'Debes enviar { claims } y uid o email.');
  }
  const targetUid = await uidFromData(data);
  const target = await getAuth().getUser(targetUid);
  const merged = withAdminFromRole(target.customClaims || {}, data.claims);
  await getAuth().setCustomUserClaims(targetUid, merged);
  return { ok: true, uid: targetUid, claims: merged };
});

// ——— deleteUser ———
// data: { uid?: string, email?: string }
exports.deleteUser = onCall({ region: 'us-central1' }, async ({ data, auth }) => {
  await requireAdmin(auth);
  const targetUid = await uidFromData(data);
  await getAuth().deleteUser(targetUid);
  return { ok: true, uid: targetUid };
});
