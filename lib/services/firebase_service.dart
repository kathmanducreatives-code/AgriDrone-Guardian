  // Updated detectionsStream method with debug logging to print Firebase data received
  Stream<List<Detection>> detectionsStream() {
    return _firestore.collection('detections').snapshots().map((snapshot) {
      debugPrint('Firebase Data Received: ${snapshot.docs}'); // Debug log
      return snapshot.docs.map((doc) {
        return Detection.fromJson(doc.data());
      }).toList();
    });
  }