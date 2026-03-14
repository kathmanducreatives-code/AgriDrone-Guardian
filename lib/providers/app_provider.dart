  init() async {
    await Future.delayed(Duration(seconds: 3));

    if (detections.isEmpty && soil.isEmpty) {
      await fetchInitialData();
    }

    // Stream listeners for updating data
    detectionsStream.listen((newData) {
      updateDetections(newData);
    });

    soilStream.listen((newSoilData) {
      updateSoilData(newSoilData);
    });
  }