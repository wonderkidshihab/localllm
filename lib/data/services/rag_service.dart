import 'dart:convert';
import 'dart:io';

import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import 'database_service.dart';

import 'package:get/get.dart';
import '../../presentation/settings/settings_controller.dart';

class RAGService {
  final DatabaseService _db;
  late OpenAIEmbeddings _embeddings;
  late MemoryVectorStore _vectorStore;
  bool _initialized = false;

  RAGService(this._db);

  Future<void> initialize() async {
    final settings = Get.find<SettingsController>();

    _embeddings = OpenAIEmbeddings(
      apiKey: 'not-needed',
      baseUrl: settings.lmStudioUrl.value,
      model: settings.embeddingsModel.value,
    );

    _vectorStore = MemoryVectorStore(embeddings: _embeddings);

    // Warm up the memory mapping from local SQLite
    final storedData = await _db.getAllEmbeddings();

    if (storedData.isNotEmpty) {
      final documents = <Document>[];
      final embeddingsList = <List<double>>[];

      for (var row in storedData) {
        final content = row['content'] as String;
        final metaJson = row['metadata'] as String;
        final vectorJson = row['vector'] as String;

        final metadata = jsonDecode(metaJson) as Map<String, dynamic>;
        final vector = (jsonDecode(vectorJson) as List).cast<double>();

        documents.add(Document(pageContent: content, metadata: metadata));
        embeddingsList.add(vector);
      }

      await _vectorStore.addVectors(vectors: embeddingsList, documents: documents);
    }

    _initialized = true;
  }

  Future<void> ingestPdf(String filePath) async {
    if (!_initialized) return;

    try {
      final bytes = File(filePath).readAsBytesSync();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();

      // Split text into chunks
      final splitter = RecursiveCharacterTextSplitter(chunkSize: 1000, chunkOverlap: 200);
      final chunks = splitter.splitText(text);

      final filename = p.basename(filePath);
      final rawDocs = chunks
          .map((chunk) => Document(pageContent: chunk.trim(), metadata: {'filename': filename}))
          .toList();

      // Compute Embeddings locally via LM Studio
      final embeddedVectors = await _embeddings.embedDocuments(rawDocs);

      // Save directly into the VectorStore and Local DB SQLite
      final dbRecords = <Map<String, dynamic>>[];
      for (int i = 0; i < rawDocs.length; i++) {
        final doc = rawDocs[i];
        final vec = embeddedVectors[i];
        final id = const Uuid().v4();

        dbRecords.add({
          'id': id,
          'content': doc.pageContent,
          'vector': jsonEncode(vec),
          'metadata': jsonEncode(doc.metadata),
        });

        _vectorStore.addVectors(vectors: [vec], documents: [doc]);
      }

      await _db.saveEmbeddings(dbRecords);
      await _db.logEvent("RAG Engine indexed PDF: $filename (${chunks.length} vectors)");
    } catch (e) {
      await _db.logEvent("RAG Engine error indexing PDF: $e");
      throw Exception("Failed to embed: $e");
    }
  }

  Future<String> queryContext(String queryText) async {
    if (!_initialized) return "";

    try {
      final results = await _vectorStore.similaritySearch(query: queryText);
      if (results.isEmpty) {
        await _db.logEvent("RAG Query: Vector store is empty. No context injected.");
        return "";
      }

      await _db.logEvent("RAG Query Success: Injected ${results.length} contextual chunks into prompt.");
      return results.map((doc) => "Source [${doc.metadata['filename']}]:\n${doc.pageContent}").join("\n\n");
    } catch (e) {
      await _db.logEvent("RAG Context Retrieval fail: $e");
      return "";
    }
  }
}
