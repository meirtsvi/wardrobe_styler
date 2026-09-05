// Request authentication (PLAN §7.2 "AuthN/AuthZ"): Firebase ID token + App Check token on every request; consumed (limited-use)
// App Check tokens only on credit-spending endpoints, purchases and merge.
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";

export type Principal = { uid: string; anonymous: boolean; appCheckConsumed: boolean };

export interface Verifier {
  verify(headers: { authorization?: string; appCheck?: string }, opts: { consume: boolean }): Promise<Principal>;
}

export class AuthError extends Error {
  constructor(public readonly status: 401 | 403, message: string) {
    super(message);
  }
}

export class FirebaseVerifier implements Verifier {
  async verify(headers: { authorization?: string; appCheck?: string }, opts: { consume: boolean }): Promise<Principal> {
    const bearer = headers.authorization?.match(/^Bearer (.+)$/)?.[1];
    if (!bearer) throw new AuthError(401, "missing bearer token");
    if (!headers.appCheck) throw new AuthError(401, "missing App Check token");
    let uid: string;
    let anonymous: boolean;
    try {
      const decoded = await getAuth().verifyIdToken(bearer);
      uid = decoded.uid;
      anonymous = decoded.firebase?.sign_in_provider === "anonymous";
    } catch {
      throw new AuthError(401, "invalid ID token");
    }
    try {
      const res = await getAppCheck().verifyToken(headers.appCheck, { consume: opts.consume });
      if (opts.consume && res.alreadyConsumed) throw new AuthError(403, "already_consumed");
    } catch (e) {
      if (e instanceof AuthError) throw e;
      throw new AuthError(401, "invalid App Check token");
    }
    return { uid, anonymous, appCheckConsumed: opts.consume };
  }
}

/** Test/dev verifier: `Authorization: Bearer uid:<uid>`; any non-empty App Check header passes. Never wire this in prod. */
export class StaticVerifier implements Verifier {
  async verify(headers: { authorization?: string; appCheck?: string }, opts: { consume: boolean }): Promise<Principal> {
    const uid = headers.authorization?.match(/^Bearer uid:(.+)$/)?.[1];
    if (!uid) throw new AuthError(401, "missing bearer token");
    if (!headers.appCheck) throw new AuthError(401, "missing App Check token");
    return { uid, anonymous: uid.startsWith("anon-"), appCheckConsumed: opts.consume };
  }
}
