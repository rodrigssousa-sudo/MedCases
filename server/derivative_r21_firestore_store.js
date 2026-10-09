'use strict';
const {DerivativeFirestoreStore}=require('./derivative_firestore_store');
class DerivativeR21FirestoreStore extends DerivativeFirestoreStore {
 constructor(db){super(db);this.collection=db.collection('_derivative_engine_r21');}
 async readyKeys(limit=10){const snapshot=await this.collection.where('status','in',['READY','CACHE_PENDING']).limit(limit).get();return snapshot.docs.map(d=>d.data().operationKey);}
}
module.exports={DerivativeR21FirestoreStore};
