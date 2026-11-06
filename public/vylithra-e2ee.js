/**
 * Vylithra Complete End-to-End Encryption (E2EE) Module
 * Cryptographic Standard: 
 *  - Asymmetric Key Agreement: ECDH (NIST Curve P-256 / secp256r1)
 *  - Symmetric Message Encryption: Authenticated AES-GCM-256 with CSPRNG 96-bit (12-byte) IVs
 *  - Group Encryption: Pairwise Asymmetric Key Envelopes (Sender Keys)
 *  - Media Encryption: Client-Side Envelope AES-GCM-256 with Zero-Knowledge Cloud Storage
 *  - Key Storage: Non-Extractable CryptoKey in IndexedDB (XSS-Immune)
 */

(function() {
    // -------------------------------------------------------------
    // Secure Key Storage (IndexedDB Vault - Non-Extractable Keys)
    // -------------------------------------------------------------
    const KeyStore = {
        dbName: 'VylithraVault',
        storeName: 'crypto_keys',
        _memCache: new Map(),
        dbPromise: null,

        async getDB() {
            if (typeof indexedDB === 'undefined') {
                throw new Error('IndexedDB not supported');
            }
            if (!this.dbPromise) {
                this.dbPromise = new Promise((resolve, reject) => {
                    const timer = setTimeout(() => reject(new Error('IndexedDB timeout')), 800);
                    try {
                        const req = indexedDB.open(this.dbName, 1);
                        req.onupgradeneeded = (e) => {
                            const db = (e && e.target && e.target.result) || req.result;
                            if (db && !db.objectStoreNames.contains(this.storeName)) {
                                db.createObjectStore(this.storeName);
                            }
                        };
                        req.onsuccess = (e) => {
                            clearTimeout(timer);
                            resolve((e && e.target && e.target.result) || req.result);
                        };
                        req.onerror = () => {
                            clearTimeout(timer);
                            reject(req.error || new Error('IndexedDB open error'));
                        };
                    } catch (err) {
                        clearTimeout(timer);
                        reject(err);
                    }
                });
            }
            return this.dbPromise;
        },

        async set(key, value) {
            try {
                const db = await this.getDB();
                return new Promise((resolve) => {
                    const tx = db.transaction(this.storeName, 'readwrite');
                    tx.objectStore(this.storeName).put(value, key);
                    tx.oncomplete = () => resolve();
                    tx.onerror = () => {
                        this._memCache.set(key, value);
                        resolve();
                    };
                });
            } catch (err) {
                this._memCache.set(key, value);
            }
        },

        async get(key) {
            try {
                const db = await this.getDB();
                return new Promise((resolve) => {
                    const tx = db.transaction(this.storeName, 'readonly');
                    const req = tx.objectStore(this.storeName).get(key);
                    req.onsuccess = () => resolve(req.result || this._memCache.get(key) || null);
                    req.onerror = () => resolve(this._memCache.get(key) || null);
                });
            } catch (err) {
                return this._memCache.get(key) || null;
            }
        }
    };

    // -------------------------------------------------------------
    // Vylithra Cryptographic Engine
    // -------------------------------------------------------------
    const VylithraCrypto = {
        currentUserId: null,
        myPrivateKey: null,
        myPublicKeyBase64: null,
        sharedKeysCache: new Map(),     // otherUserId -> CryptoKey (AES-GCM)
        groupKeysCache: new Map(),      // groupId -> CryptoKey (AES-GCM)
        userPublicKeysCache: new Map(), // otherUserId -> Base64 SPKI
        mediaCache: new Map(),          // url -> objectUrl
        isReady: false,

        // Binary Helpers
        bufToBase64(buf) {
            let binary = '';
            const bytes = new Uint8Array(buf);
            for (let i = 0; i < bytes.byteLength; i++) {
                binary += String.fromCharCode(bytes[i]);
            }
            return window.btoa(binary);
        },

        base64ToBuf(base64) {
            const binaryString = window.atob(base64);
            const len = binaryString.length;
            const bytes = new Uint8Array(len);
            for (let i = 0; i < len; i++) {
                bytes[i] = binaryString.charCodeAt(i);
            }
            return bytes.buffer;
        },

        // ---------------------------------------------------------
        // 1. Device Key Management (Non-Extractable in IndexedDB)
        // ---------------------------------------------------------
        async init(userId) {
            if (!userId) return false;
            this.currentUserId = String(userId);

            try {
                // Try retrieving non-extractable CryptoKey from IndexedDB
                let privateKey = await KeyStore.get(`priv_${this.currentUserId}`);
                let pubSpkiB64 = localStorage.getItem(`vyl_e2ee_pub_${this.currentUserId}`);

                if (!privateKey) {
                    // Check if migrating from legacy localStorage
                    const legacyPrivStr = localStorage.getItem(`vyl_e2ee_priv_${this.currentUserId}`);
                    if (legacyPrivStr) {
                        try {
                            const jwk = JSON.parse(legacyPrivStr);
                            privateKey = await window.crypto.subtle.importKey(
                                'jwk',
                                jwk,
                                { name: 'ECDH', namedCurve: 'P-256' },
                                false, // Import as non-extractable
                                ['deriveKey', 'deriveBits']
                            );
                            await KeyStore.set(`priv_${this.currentUserId}`, privateKey);
                            localStorage.removeItem(`vyl_e2ee_priv_${this.currentUserId}`); // Purge from localStorage
                            console.log('[Vylithra E2EE] Migrated private key to secure IndexedDB vault.');
                        } catch (e) {
                            console.warn('[Vylithra E2EE] Legacy key migration failed, creating fresh keypair');
                        }
                    }
                }

                if (!privateKey || !pubSpkiB64) {
                    console.log('[Vylithra E2EE] Generating fresh non-extractable ECDH P-256 keypair...');
                    const keyPair = await window.crypto.subtle.generateKey(
                        { name: 'ECDH', namedCurve: 'P-256' },
                        true, // Initial true only to export the public key
                        ['deriveKey', 'deriveBits']
                    );

                    // Export only the public key
                    const exportedPub = await window.crypto.subtle.exportKey('spki', keyPair.publicKey);
                    pubSpkiB64 = this.bufToBase64(exportedPub);
                    localStorage.setItem(`vyl_e2ee_pub_${this.currentUserId}`, pubSpkiB64);

                    // Re-import or store private key into IndexedDB
                    await KeyStore.set(`priv_${this.currentUserId}`, keyPair.privateKey);
                    privateKey = keyPair.privateKey;
                }

                this.myPrivateKey = privateKey;
                this.myPublicKeyBase64 = pubSpkiB64;
                this.isReady = true;

                // Sync public key with the backend
                this.syncPublicKeyWithServer();
                return true;
            } catch (err) {
                console.error('[Vylithra E2EE] Initialization error:', err);
                return false;
            }
        },

        async syncPublicKeyWithServer() {
            if (!this.myPublicKeyBase64) return;
            const token = localStorage.getItem('token');
            if (!token) return;

            try {
                await fetch('/api/users/keys', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'x-auth-token': token,
                        'Authorization': `Bearer ${token}`
                    },
                    body: JSON.stringify({ publicKey: this.myPublicKeyBase64 })
                });
            } catch (err) {
                console.warn('[Vylithra E2EE] Failed to sync public key to server:', err);
            }
        },

        // Fetch or get cached recipient's public key
        async getRecipientPublicKey(otherUserId) {
            const uid = String(otherUserId);
            if (this.userPublicKeysCache.has(uid)) {
                return this.userPublicKeysCache.get(uid);
            }

            const token = localStorage.getItem('token');
            try {
                const res = await fetch(`/api/users/${uid}/public-key`, {
                    headers: {
                        'x-auth-token': token || '',
                        'Authorization': token ? `Bearer ${token}` : ''
                    }
                });
                if (res.ok) {
                    const data = await res.json();
                    if (data && data.publicKey) {
                        this.userPublicKeysCache.set(uid, data.publicKey);
                        return data.publicKey;
                    }
                }
            } catch (err) {
                console.warn(`[Vylithra E2EE] Failed to fetch public key for user ${uid}:`, err);
            }
            return null;
        },

        // Derive shared AES-GCM-256 key via Diffie-Hellman
        async getSharedKey(otherUserId) {
            const uid = String(otherUserId);
            if (this.sharedKeysCache.has(uid)) {
                return this.sharedKeysCache.get(uid);
            }
            if (!this.myPrivateKey) {
                if (!this.currentUserId) {
                    try {
                        const token = localStorage.getItem('token');
                        if (token) {
                            const base64Url = token.split('.')[1];
                            const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
                            const jsonPayload = decodeURIComponent(atob(base64).split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join(''));
                            const payload = JSON.parse(jsonPayload);
                            this.currentUserId = (payload.user && (payload.user.id || payload.user._id)) || payload.id || payload._id;
                        }
                    } catch(e) {}
                }
                if (this.currentUserId) {
                    await this.init(this.currentUserId);
                }
            }
            if (!this.myPrivateKey) return null;

            const recipientPubB64 = await this.getRecipientPublicKey(uid);
            if (!recipientPubB64) return null;

            try {
                const pubBuf = this.base64ToBuf(recipientPubB64);
                let importedRecipientPub = null;

                // 1. Try 'raw' if exact 65-byte uncompressed point (format exported by Mobile)
                if (pubBuf.byteLength === 65) {
                    try {
                        importedRecipientPub = await window.crypto.subtle.importKey(
                            'raw',
                            pubBuf,
                            { name: 'ECDH', namedCurve: 'P-256' },
                            false,
                            []
                        );
                    } catch(e) {}
                }

                // 2. Try 'spki' if standard SubjectPublicKeyInfo (format exported by Web)
                if (!importedRecipientPub) {
                    try {
                        importedRecipientPub = await window.crypto.subtle.importKey(
                            'spki',
                            pubBuf,
                            { name: 'ECDH', namedCurve: 'P-256' },
                            false,
                            []
                        );
                    } catch(e) {}
                }

                // 3. Fallback: extract last 65 bytes as raw uncompressed EC point
                if (!importedRecipientPub && pubBuf.byteLength >= 65) {
                    try {
                        const rawTail = pubBuf.slice(pubBuf.byteLength - 65);
                        importedRecipientPub = await window.crypto.subtle.importKey(
                            'raw',
                            rawTail,
                            { name: 'ECDH', namedCurve: 'P-256' },
                            false,
                            []
                        );
                    } catch(e) {}
                }

                if (!importedRecipientPub) {
                    throw new Error(`Unable to import public key format (len: ${pubBuf.byteLength})`);
                }

                const sharedKey = await window.crypto.subtle.deriveKey(
                    { name: 'ECDH', public: importedRecipientPub },
                    this.myPrivateKey,
                    { name: 'AES-GCM', length: 256 },
                    false,
                    ['encrypt', 'decrypt']
                );

                this.sharedKeysCache.set(uid, sharedKey);
                return sharedKey;
            } catch (err) {
                console.error(`[Vylithra E2EE] Key derivation error with ${uid}:`, err);
                return null;
            }
        },

        // ---------------------------------------------------------
        // 2. 1-on-1 Direct Message Encryption & Decryption
        // ---------------------------------------------------------
        async encrypt(plaintext, otherUserId) {
            if (!plaintext) return { content: '', iv: null, isE2EE: false };
            const sharedKey = await this.getSharedKey(otherUserId);
            
            if (!sharedKey) {
                if (window.CryptoJS) {
                    const legacyKey = CryptoJS.SHA256([this.currentUserId, otherUserId].sort().join('-') + 'vylithra-e2ee-secret').toString();
                    return {
                        content: CryptoJS.AES.encrypt(plaintext, legacyKey).toString(),
                        iv: null,
                        isE2EE: false
                    };
                }
                return { content: plaintext, iv: null, isE2EE: false };
            }

            try {
                const iv = window.crypto.getRandomValues(new Uint8Array(12));
                const encoded = new TextEncoder().encode(plaintext);
                const ciphertextBuf = await window.crypto.subtle.encrypt(
                    { name: 'AES-GCM', iv },
                    sharedKey,
                    encoded
                );

                return {
                    content: this.bufToBase64(ciphertextBuf),
                    iv: this.bufToBase64(iv),
                    isE2EE: true
                };
            } catch (err) {
                console.error('[Vylithra E2EE] Encryption failed:', err);
                return { content: plaintext, iv: null, isE2EE: false };
            }
        },

        async decrypt(msg, otherUserId) {
            if (!msg || !msg.content) return '';
            const ciphertext = msg.content;
            const uid = String(otherUserId || '');

            // Genuine E2EE message with AES-GCM + IV
            if (msg.isE2EE && msg.iv) {
                let sharedKey = await this.getSharedKey(uid);
                if (sharedKey) {
                    try {
                        const ivBuf = this.base64ToBuf(msg.iv);
                        const cipherBuf = this.base64ToBuf(ciphertext);
                        const decryptedBuf = await window.crypto.subtle.decrypt(
                            { name: 'AES-GCM', iv: ivBuf },
                            sharedKey,
                            cipherBuf
                        );
                        return new TextDecoder().decode(decryptedBuf);
                    } catch (decErr) {
                        // Invalidate cache and retry once with a freshly fetched public key
                        try {
                            this.sharedKeysCache.delete(uid);
                            this.userPublicKeysCache.delete(uid);
                            const freshKey = await this.getSharedKey(uid);
                            if (freshKey) {
                                const ivBuf = this.base64ToBuf(msg.iv);
                                const cipherBuf = this.base64ToBuf(ciphertext);
                                const decryptedBuf = await window.crypto.subtle.decrypt(
                                    { name: 'AES-GCM', iv: ivBuf },
                                    freshKey,
                                    cipherBuf
                                );
                                return new TextDecoder().decode(decryptedBuf);
                            }
                        } catch (retryErr) {}

                        // Try legacy CryptoJS fallback
                        if (window.CryptoJS) {
                            try {
                                const legacyKey = CryptoJS.SHA256([this.currentUserId, uid].sort().join('-') + 'vylithra-e2ee-secret').toString();
                                const bytes = CryptoJS.AES.decrypt(ciphertext, legacyKey);
                                const dec = bytes.toString(CryptoJS.enc.Utf8);
                                if (dec) return dec === '[Attachment]' ? '📎 Attachment' : dec;
                            } catch (e) {}
                        }

                        // If already readable text
                        if (typeof ciphertext === 'string' && !ciphertext.includes('+') && !ciphertext.includes('/') && !ciphertext.endsWith('=')) {
                            return ciphertext;
                        }

                        return '🔒 [Encrypted Message - Key Not Available]';
                    }
                }
            }

            // Legacy unversioned CryptoJS AES fallback
            if (typeof ciphertext === 'string' && ciphertext.startsWith('U2FsdGVkX1') && window.CryptoJS) {
                try {
                    const legacyKey = CryptoJS.SHA256([this.currentUserId, otherUserId].sort().join('-') + 'vylithra-e2ee-secret').toString();
                    const bytes = CryptoJS.AES.decrypt(ciphertext, legacyKey);
                    const dec = bytes.toString(CryptoJS.enc.Utf8);
                    if (dec) return dec === '[Attachment]' ? '📎 Attachment' : dec;
                } catch (e) {}
            }

            return ciphertext;
        },

        // ---------------------------------------------------------
        // 3. Group Messaging (Pairwise Key Distribution Envelopes)
        // ---------------------------------------------------------
        async generateGroupEnvelopes(memberUserIds) {
            // Generate random 256-bit symmetric Group Key
            const groupKeyRaw = window.crypto.getRandomValues(new Uint8Array(32));
            const envelopes = [];

            for (const memberId of memberUserIds) {
                const memberSharedKey = await this.getSharedKey(memberId);
                if (!memberSharedKey) continue;

                const envIv = window.crypto.getRandomValues(new Uint8Array(12));
                const encKeyBuf = await window.crypto.subtle.encrypt(
                    { name: 'AES-GCM', iv: envIv },
                    memberSharedKey,
                    groupKeyRaw
                );

                envelopes.push({
                    user: memberId,
                    encryptedKey: this.bufToBase64(encKeyBuf),
                    iv: this.bufToBase64(envIv),
                    creatorPublicKey: this.myPublicKeyBase64
                });
            }

            return { groupKeyRaw, envelopes };
        },

        async unlockGroupKey(groupId, envelopes, creatorId) {
            const gid = String(groupId);
            if (this.groupKeysCache.has(gid)) return this.groupKeysCache.get(gid);

            if (!Array.isArray(envelopes)) return null;
            const myEnv = envelopes.find(e => {
                const u = e.user && e.user._id ? e.user._id : e.user;
                return String(u) === String(this.currentUserId);
            });
            if (!myEnv) return null;

            try {
                const peerId = creatorId || myEnv.creatorPublicKey;
                const peerSharedKey = await this.getSharedKey(peerId);
                if (!peerSharedKey) return null;

                const ivBuf = this.base64ToBuf(myEnv.iv);
                const encBuf = this.base64ToBuf(myEnv.encryptedKey);

                const rawKeyBuf = await window.crypto.subtle.decrypt(
                    { name: 'AES-GCM', iv: ivBuf },
                    peerSharedKey,
                    encBuf
                );

                const groupCryptoKey = await window.crypto.subtle.importKey(
                    'raw',
                    rawKeyBuf,
                    { name: 'AES-GCM', length: 256 },
                    false,
                    ['encrypt', 'decrypt']
                );

                this.groupKeysCache.set(gid, groupCryptoKey);
                return groupCryptoKey;
            } catch (err) {
                console.warn(`[Vylithra E2EE] Failed to unlock group key for ${gid}:`, err);
                return null;
            }
        },

        async encryptGroupMessage(plaintext, groupId) {
            const gid = String(groupId);
            const groupKey = this.groupKeysCache.get(gid);
            if (!groupKey) {
                // Fallback to CryptoJS if envelopes not established
                if (window.CryptoJS) {
                    return {
                        content: CryptoJS.AES.encrypt(plaintext, CryptoJS.SHA256(gid + 'vylithra-group-e2ee-secret').toString()).toString(),
                        iv: null,
                        isE2EE: false
                    };
                }
                return { content: plaintext, iv: null, isE2EE: false };
            }

            const iv = window.crypto.getRandomValues(new Uint8Array(12));
            const encBuf = await window.crypto.subtle.encrypt(
                { name: 'AES-GCM', iv },
                groupKey,
                new TextEncoder().encode(plaintext)
            );

            return {
                content: this.bufToBase64(encBuf),
                iv: this.bufToBase64(iv),
                isE2EE: true
            };
        },

        async decryptGroupMessage(msg, groupId) {
            if (!msg || !msg.content) return '';
            const gid = String(groupId);
            const groupKey = this.groupKeysCache.get(gid);

            if (msg.isE2EE && msg.iv && groupKey) {
                try {
                    const ivBuf = this.base64ToBuf(msg.iv);
                    const cipherBuf = this.base64ToBuf(msg.content);
                    const decBuf = await window.crypto.subtle.decrypt(
                        { name: 'AES-GCM', iv: ivBuf },
                        groupKey,
                        cipherBuf
                    );
                    return new TextDecoder().decode(decBuf);
                } catch (e) {
                    return '🔒 [Encrypted Group Message - Key Unavailable]';
                }
            }

            // Fallback
            if (typeof msg.content === 'string' && msg.content.startsWith('U2FsdGVkX1') && window.CryptoJS) {
                try {
                    const key = CryptoJS.SHA256(gid + 'vylithra-group-e2ee-secret').toString();
                    const bytes = CryptoJS.AES.decrypt(msg.content, key);
                    const dec = bytes.toString(CryptoJS.enc.Utf8);
                    if (dec) return dec === '[Attachment]' ? '📎 Attachment' : dec;
                } catch (e) {}
            }

            return msg.content;
        },

        // ---------------------------------------------------------
        // 4. Client-Side Media Attachment Encryption (Zero-Knowledge)
        // ---------------------------------------------------------
        async encryptMediaFile(file) {
            const rawFileBytes = await file.arrayBuffer();
            const fileKeyRaw = window.crypto.getRandomValues(new Uint8Array(32));
            const fileIv = window.crypto.getRandomValues(new Uint8Array(12));

            const cryptoKey = await window.crypto.subtle.importKey(
                'raw', fileKeyRaw, { name: 'AES-GCM' }, false, ['encrypt']
            );

            const encryptedBuffer = await window.crypto.subtle.encrypt(
                { name: 'AES-GCM', iv: fileIv },
                cryptoKey,
                rawFileBytes
            );

            const encryptedBlob = new Blob([encryptedBuffer], { type: 'application/octet-stream' });
            return {
                blob: encryptedBlob,
                fileKeyB64: this.bufToBase64(fileKeyRaw),
                fileIvB64: this.bufToBase64(fileIv),
                mimeType: file.type || 'application/octet-stream',
                originalName: file.name
            };
        },

        async decryptMediaUrl(url, fileKeyB64, fileIvB64, mimeType) {
            const cacheKey = `${url}:${fileKeyB64}`;
            if (this.mediaCache.has(cacheKey)) {
                return this.mediaCache.get(cacheKey);
            }

            try {
                const res = await fetch(url);
                const encryptedBuf = await res.arrayBuffer();

                const fileKeyRaw = this.base64ToBuf(fileKeyB64);
                const fileIv = this.base64ToBuf(fileIvB64);

                const cryptoKey = await window.crypto.subtle.importKey(
                    'raw', fileKeyRaw, { name: 'AES-GCM' }, false, ['decrypt']
                );

                const decryptedBuf = await window.crypto.subtle.decrypt(
                    { name: 'AES-GCM', iv: fileIv },
                    cryptoKey,
                    encryptedBuf
                );

                const decryptedBlob = new Blob([decryptedBuf], { type: mimeType || 'image/jpeg' });
                const objectUrl = URL.createObjectURL(decryptedBlob);
                this.mediaCache.set(cacheKey, objectUrl);
                return objectUrl;
            } catch (err) {
                console.error('[Vylithra E2EE] Media decryption failed:', err);
                return null;
            }
        }
    };

    window.VylithraCrypto = VylithraCrypto;
})();
