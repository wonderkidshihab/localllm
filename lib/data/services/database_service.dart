import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


class DatabaseService {
  Database? _db;

  Future<void> initialize() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'local_agency.db');

    _db = await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT,
        content TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE leads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        businessName TEXT,
        contactInfo TEXT,
        marketingGaps TEXT,
        source TEXT,
        outreachDraft TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_threads (
        id TEXT PRIMARY KEY,
        title TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        threadId TEXT,
        role TEXT,
        text TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE embeddings (
        id TEXT PRIMARY KEY,
        content TEXT,
        vector TEXT,
        metadata TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE chat_threads (
          id TEXT PRIMARY KEY,
          title TEXT,
          timestamp TEXT
        )
      ''');
      
      final defaultThreadId = "legacy_thread";
      await db.insert('chat_threads', {
         'id': defaultThreadId,
         'title': 'Legacy Conversation',
         'timestamp': DateTime.now().toIso8601String()
      });

      await db.execute('ALTER TABLE chats ADD COLUMN threadId TEXT DEFAULT "legacy_thread"');
    }
    
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE embeddings (
          id TEXT PRIMARY KEY,
          content TEXT,
          vector TEXT,
          metadata TEXT
        )
      ''');
    }
    
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE leads ADD COLUMN outreachDraft TEXT');
    }
  }

  // --- Leads Methods ---
  Future<void> saveLead(String businessName, String contactInfo, String gaps, String source, [String? outreachDraft]) async {
    if (_db == null) return;
    await _db!.insert('leads', {
      'businessName': businessName,
      'contactInfo': contactInfo,
      'marketingGaps': gaps,
      'source': source,
      'outreachDraft': outreachDraft ?? '',
      'timestamp': DateTime.now().toIso8601String()
    });
    await logEvent("Lead saved: $businessName");
  }

  Future<List<Map<String, dynamic>>> getLeads() async {
    if (_db == null) return [];
    return await _db!.query('leads', orderBy: 'timestamp DESC');
  }

  Future<void> deleteLead(int id) async {
    if (_db == null) return;
    await _db!.delete('leads', where: 'id = ?', whereArgs: [id]);
    await logEvent("Deleted lead #$id");
  }

  // --- Threads Methods ---
  Future<void> createChatThread(String id, String title) async {
    if (_db == null) return;
    await _db!.insert('chat_threads', {
       'id': id,
       'title': title,
       'timestamp': DateTime.now().toIso8601String()
    });
    await logEvent("Created new thread: $id");
  }

  Future<void> renameChatThread(String id, String newTitle) async {
    if (_db == null) return;
    await _db!.update('chat_threads', {'title': newTitle}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getChatThreads() async {
    if (_db == null) return [];
    return await _db!.query('chat_threads', orderBy: 'timestamp DESC');
  }

  Future<void> deleteChatThread(String id) async {
    if (_db == null) return;
    await _db!.delete('chat_threads', where: 'id = ?', whereArgs: [id]);
    await _db!.delete('chats', where: 'threadId = ?', whereArgs: [id]);
    await logEvent("Deleted heavily loaded chat thread $id");
  }

  // --- Chats Methods ---
  Future<void> saveChat(String threadId, String role, String text) async {
    if (_db == null) return;
    await _db!.insert('chats', {
      'threadId': threadId,
      'role': role,
      'text': text,
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  Future<List<Map<String, dynamic>>> getChatsForThread(String threadId) async {
    if (_db == null) return [];
    return await _db!.query('chats', where: 'threadId = ?', whereArgs: [threadId], orderBy: 'timestamp ASC');
  }
  
  Future<List<Map<String, dynamic>>> getChats() async {
    if (_db == null) return [];
    return await _db!.query('chats', orderBy: 'timestamp ASC');
  }

  // --- Logs Methods ---
  Future<void> logEvent(String event) async {
    if (_db == null) return;
    await _db!.insert('logs', {
      'event': event,
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    if (_db == null) return [];
    return await _db!.query('logs', orderBy: 'timestamp DESC');
  }

  Future<void> clearLogs() async {
    if (_db == null) return;
    await _db!.delete('logs');
  }

  Future<void> clearDatabase() async {
    if (_db == null) return;
    await _db!.delete('leads');
    await _db!.delete('chat_threads');
    await _db!.delete('chats');
    await _db!.delete('embeddings');
    await _db!.delete('documents');
    await clearLogs();
  }

  // --- Embeddings Methods ---
  Future<void> saveEmbeddings(List<Map<String, dynamic>> records) async {
    if (_db == null) return;
    
    await _db!.transaction((txn) async {
      for (final record in records) {
        await txn.insert('embeddings', record, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllEmbeddings() async {
    if (_db == null) return [];
    return await _db!.query('embeddings');
  }
}
