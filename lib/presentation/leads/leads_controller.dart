import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/database_service.dart';

class LeadsController extends GetxController {
  final DatabaseService _db = Get.find<DatabaseService>();

  final RxList<Map<String, dynamic>> leads = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  
  // Selection Logic
  final RxBool isSelectionMode = false.obs;
  final RxSet<int> selectedIds = <int>{}.obs;

  // Undo / Deletion Buffer
  final Map<int, Map<String, dynamic>> _undoBuffer = {};
  final Map<int, Timer> _activeTimers = {};

  @override
  void onInit() {
    super.onInit();
    fetchLeads();
  }

  Future<void> fetchLeads() async {
    isLoading.value = true;
    try {
      final fetched = await _db.getLeads();
      leads.assignAll(fetched);
    } finally {
      isLoading.value = false;
    }
  }

  void toggleSelectionMode() {
    isSelectionMode.value = !isSelectionMode.value;
    if (!isSelectionMode.value) {
      selectedIds.clear();
    }
  }

  void toggleLeadSelection(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    
    if (selectedIds.isEmpty) {
      isSelectionMode.value = false;
    }
  }

  // --- Deletion Logic ---

  Future<void> requestSingleDeletion(Map<String, dynamic> lead) async {
    final id = lead['id'] as int;
    
    // Remove from UI immediately
    final index = leads.indexWhere((l) => l['id'] == id);
    if (index != -1) {
      _undoBuffer[id] = Map.from(lead);
      leads.removeAt(index);
      
      _startDeletionTimer(id);
      
      Get.snackbar(
        "Lead Removed", 
        "Deleted ${lead['businessName']}",
        mainButton: TextButton(
          onPressed: () => undoDeletion(id, index),
          child: const Text("UNDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _startDeletionTimer(int id) {
    _activeTimers[id]?.cancel();
    _activeTimers[id] = Timer(const Duration(seconds: 5), () async {
      if (_undoBuffer.containsKey(id)) {
        await _db.deleteLead(id);
        _undoBuffer.remove(id);
        _activeTimers.remove(id);
      }
    });
  }

  void undoDeletion(int id, int originalIndex) {
    final lead = _undoBuffer.remove(id);
    if (lead != null) {
      _activeTimers[id]?.cancel();
      _activeTimers.remove(id);
      
      // Add back to UI at correct position if possible, else just add
      if (originalIndex <= leads.length) {
        leads.insert(originalIndex, lead);
      } else {
        leads.add(lead);
      }
      
      if (Get.isSnackbarOpen) {
        Get.back();
      }
    }
  }

  Future<void> deleteSelected() async {
    if (selectedIds.isEmpty) return;

    final idsToDelete = List<int>.from(selectedIds);
    toggleSelectionMode(); // Exit selection mode

    for (final id in idsToDelete) {
      final lead = leads.firstWhereOrNull((l) => l['id'] == id);
      if (lead != null) {
        final index = leads.indexOf(lead);
        _undoBuffer[id] = Map.from(lead);
        leads.removeAt(index);
        _startDeletionTimer(id);
      }
    }

    Get.snackbar(
      "Cleanup Complete", 
      "Purged ${idsToDelete.length} leads.",
      mainButton: TextButton(
        onPressed: () {
          for (final id in idsToDelete) {
             // Find roughly where to put them back
             undoDeletion(id, 0); 
          }
        },
        child: const Text("UNDO ALL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      duration: const Duration(seconds: 5),
    );
  }
}
