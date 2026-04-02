import re

with open('lib/screens/drone_control_screen.dart', 'r') as f:
    content = f.read()

# Insert dart:ui
content = content.replace("import 'dart:typed_data';", "import 'dart:typed_data';\nimport 'dart:ui';")

# Find the build method
match = re.search(r'  @override\n  Widget build\(BuildContext context\) \{', content)
if not match:
    print("Could not find build method!")
    exit(1)

prefix = content[:match.start()]

new_ui = """  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DroneControlProvider>();
    final app = context.watch<AppProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF020617), // Deep slate background
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
             decoration: const BoxDecoration(
               gradient: LinearGradient(
                 colors: [Color(0xFF020617), Color(0xFF0F172A)],
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
               ),
             ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('ESP32 Command Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          bottom: const TabBar(
            labelColor: Color(0xFF10B981), // Neon Emerald
            unselectedLabelColor: Colors.white54,
            indicatorColor: Color(0xFF10B981),
            indicatorWeight: 3,
            dividerColor: Colors.white10,
            tabs: [
              Tab(icon: Icon(Icons.speed), text: "Mission Control"),
              Tab(icon: Icon(Icons.bug_report), text: "Diagnostics & Testing"),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5,
              colors: [Color(0xFF064E3B), Color(0xFF020617)], // Dark emerald to almost black
            ),
          ),
          child: TabBarView(
            children: [
              // TAB 1: MISSION CONTROL
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildConnectionSection(provider),
                    const SizedBox(height: 16),
                    _buildDeviceStatusSection(provider),
                    const SizedBox(height: 16),
                    _buildControlsSection(provider),
                    const SizedBox(height: 16),
                    _buildActionLogs(provider),
                  ],
                ),
              ),
              
              // TAB 2: DIAGNOSTICS & TESTING
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFirebaseDiagnosticsSection(app),
                    const SizedBox(height: 16),
                    _buildBackendTestingSection(),
                    const SizedBox(height: 16),
                    _buildRawTelemetrySection(app),
                    const SizedBox(height: 16),
                    _buildBackendInfoSection(provider),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*
   * ---------------------------------------------------------
   * SECTION: MISSION CONTROL WIDGETS
   * ---------------------------------------------------------
   */

  Widget _buildConnectionSection(DroneControlProvider provider) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.router, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              const Text('Local Network', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              _buildStatusChip(provider.connectionStatus),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'ESP32 IP Address',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton.icon(
                  onPressed: provider.isPinging ? null : () {
                    provider.updateIp(_ipController.text);
                    provider.pingDevice();
                  },
                  icon: provider.isPinging
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sensors, color: Colors.white),
                  label: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(DeviceStatus status) {
    Color color;
    String label;
    bool isGlowing = false;
    switch (status) {
      case DeviceStatus.reachable: color = const Color(0xFF10B981); label = 'Connected'; isGlowing = true; break;
      case DeviceStatus.connecting: color = const Color(0xFFF59E0B); label = 'Connecting...'; isGlowing = true; break;
      case DeviceStatus.unreachable: color = const Color(0xFFEF4444); label = 'Unreachable'; break;
      case DeviceStatus.unstable: color = const Color(0xFFF59E0B); label = 'Unstable'; break;
      case DeviceStatus.disconnected: color = Colors.white54; label = 'Disconnected'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: color.withOpacity(0.5)),
        boxShadow: isGlowing ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)] : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGlowing) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusSection(DroneControlProvider provider) {
    final state = provider.deviceState;
    if (state.isEmpty && provider.connectionStatus != DeviceStatus.reachable) return const SizedBox.shrink();
    
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.memory, color: Color(0xFF3B82F6))),
              const SizedBox(width: 12),
              const Text('Hardware Telemetry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildMetricRing('Flight State', state['flight_state']?.toString() ?? 'IDLE', const Color(0xFF3B82F6))),
              Expanded(child: _buildMetricRing('Patches', state['buffered_patches']?.toString() ?? '0', const Color(0xFF8B5CF6))),
              Expanded(child: _buildMetricRing('GPS Fix', state['gps_fix'] == true ? 'YES' : 'NO', state['gps_fix'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1)),
          if (state['lat'] != null) _buildStatusRow('Location', "${state['lat']}, ${state['lon']}"),
          _buildStatusRow('Upload State', state['upload_state']?.toString() ?? 'IDLE'),
          _buildStatusRow('Last Sync', state['last_response_time']?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildMetricRing(String label, String value, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(value: 1.0, strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.2))),
            ),
            SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(value: 0.7, strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(color)),
            ),
            Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: value.length > 4 ? 12 : 16)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildControlsSection(DroneControlProvider provider) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.gamepad, color: Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              const Text('Operator Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.8,
            children: [
              _buildModernButton('Start Flight', Icons.flight_takeoff, provider.triggerFlightStart, provider.isActionButtonActive, const Color(0xFF3B82F6)),
              _buildModernButton('Capture', Icons.camera, provider.triggerCapture, provider.isActionButtonActive, const Color(0xFF10B981)),
              _buildModernButton('Stop Flight', Icons.flight_land, provider.triggerStopFlight, provider.isActionButtonActive, const Color(0xFFF59E0B)),
              _buildModernButton('Upload', Icons.cloud_upload, provider.triggerUpload, provider.isActionButtonActive, const Color(0xFF8B5CF6)),
              _buildModernButton('Force Done', Icons.check_circle, provider.forceBackendCompletion, provider.isBackendLoading, const Color(0xFF0EA5E9)),
              _buildModernButton('Reboot', Icons.restart_alt, provider.triggerReboot, provider.isActionButtonActive, const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernButton(String label, IconData icon, VoidCallback action, bool isLoading, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading ? null : action,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionLogs(DroneControlProvider provider) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white54),
              const SizedBox(width: 8),
              const Text('Console Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
            child: provider.actionLogs.isEmpty
                ? const Text('Awaiting commands...', style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.actionLogs.length > 5 ? 5 : provider.actionLogs.length,
                    itemBuilder: (ctx, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text("> ${provider.actionLogs[i]}", style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF10B981))),
                      );
                    },
            ),
          )
        ],
      ),
    );
  }

  /*
   * ---------------------------------------------------------
   * SECTION: DIAGNOSTICS & TESTING WIDGETS
   * ---------------------------------------------------------
   */
  
  Widget _buildFirebaseDiagnosticsSection(AppProvider app) {
    final status = app.droneStatus;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF97316).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.cloud, color: Color(0xFFF97316))),
              const SizedBox(width: 12),
              const Text('Firebase Cloud Stream', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDataPill('Mission', status?.isActive == true ? 'ACTIVE' : 'IDLE', status?.isActive == true ? const Color(0xFFF59E0B) : const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildDataPill('Target', app.selectedCropType.toUpperCase(), const Color(0xFF3B82F6))),
              const SizedBox(width: 8),
              Expanded(child: _buildDataPill('Firebase', app.firebaseConnected ? 'CONNECTED' : 'OFFLINE', app.firebaseConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildValuedText('Battery:', '${status?.battery ?? 0}%', Colors.white),
                const SizedBox(height: 4),
                _buildValuedText('State:', status?.flying == true ? 'AIRBORNE' : 'GROUNDED', status?.flying == true ? const Color(0xFF3B82F6) : Colors.white54),
                const SizedBox(height: 4),
                _buildValuedText('Latest Image:', status?.latestImageUrl != null ? 'Valid URL' : 'None', const Color(0xFF10B981)),
                const SizedBox(height: 12),
                Text(
                  app.detections.isEmpty
                      ? 'No AI logs on this node yet.'
                      : 'AI: ${app.detections.first.crop} -> ${app.detections.first.disease} (${(app.detections.first.confidence * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildValuedText(String label, String value, Color valueColor) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBackendTestingSection() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Render App Integrity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Simulate image inferences proactively.', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    selectedForegroundColor: Colors.white,
                    selectedBackgroundColor: const Color(0xFF8B5CF6).withOpacity(0.5),
                  ),
                  segments: const [
                    ButtonSegment(value: 'rice', label: Text('Rice', style: TextStyle(color: Colors.white))),
                    ButtonSegment(value: 'wheat', label: Text('Wheat', style: TextStyle(color: Colors.white))),
                  ],
                  selected: {_backendCrop},
                  onSelectionChanged: (v) => setState(() => _backendCrop = v.first),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.attach_file, color: Colors.white),
                label: const Text('Select file', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
            ],
          ),
          if (_selectedFileName != null)...[
            const SizedBox(height: 8),
            Text("File: $_selectedFileName", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          if (_selectedImageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_selectedImageBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadSelectedImage,
                icon: _isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: const Text('Send Inference Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          if (_backendError != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_backendError!, style: const TextStyle(color: Color(0xFFEF4444))),
            ),
          if (_backendResult != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text('${_backendResult!['disease']} (${_backendResult!['confidence']})', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Visual Render Graph', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshLatestImage),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                _backend.latestDebugImageUrl(cacheBust: _latestImageVersion),
                fit: BoxFit.cover,
                 errorBuilder: (_, __, ___) => Container(color: Colors.black45, child: const Center(child: Icon(Icons.broken_image, color: Colors.white38))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawTelemetrySection(AppProvider app) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEAB308).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.terminal, color: Color(0xFFEAB308))),
              const SizedBox(width: 12),
              const Text('Raw Local Stream', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<String>(
            stream: app.rawDroneStream,
            builder: (context, snapshot) {
              return Container(
                height: 140,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    snapshot.data ?? 'listening on socket...',
                    style: const TextStyle(color: Color(0xFF10B981), fontFamily: 'monospace', fontSize: 13, height: 1.5),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackendInfoSection(DroneControlProvider provider) {
    if (provider.activeFlightId == null) return const SizedBox.shrink();
    final bs = provider.backendState;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.cloud_sync, color: Color(0xFF0EA5E9))),
              const SizedBox(width: 12),
              const Text('Flight API Tracking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1)),
          _buildStatusRow('Flight ID', provider.activeFlightId ?? ''),
          _buildStatusRow('Backend State', bs['status']?.toString() ?? 'PROCESSING', color: const Color(0xFF0EA5E9)),
          _buildStatusRow('Images Uploaded', bs['images_uploaded']?.toString() ?? '0', color: Colors.white),
          _buildStatusRow('Failed/Retries', bs['failed_retries']?.toString() ?? '0'),
          if (bs['status'] == 'COMPLETED' && bs['summary'] != null) ...[
             const SizedBox(height: 12),
             const Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(12),
               margin: const EdgeInsets.only(top: 8),
               decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.05))),
               child: Text(bs['summary'].toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70)),
             )
          ]
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white54)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.white)),
        ],
      ),
    );
  }
  
  Widget _buildDataPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/**
 * Reusable Glassmorphism Card Container
 */
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}
"""

with open('lib/screens/drone_control_screen.dart', 'w') as f:
    f.write(prefix + new_ui)

print("Rewrote UI!")
