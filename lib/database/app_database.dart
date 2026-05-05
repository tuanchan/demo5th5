import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, 'list_card.db');

    print("DATABASE PATH: $path");

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE languages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        nativeName TEXT,
        code TEXT NOT NULL UNIQUE,
        ttsCode TEXT,
        scriptType TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        languageId INTEGER,
        languageName TEXT,
        languageCode TEXT NOT NULL,
        cardCount INTEGER DEFAULT 0,
        isFavorite INTEGER DEFAULT 0,
        isArchived INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        deletedAt TEXT,

        FOREIGN KEY (languageId) REFERENCES languages(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId INTEGER NOT NULL,

        term TEXT NOT NULL,
        definition TEXT NOT NULL,
        pronunciation TEXT,

        rawText TEXT,
        inputFormat TEXT,

        extraMeaning TEXT,
        note TEXT,
        imagePath TEXT,
        audioPath TEXT,

        position INTEGER DEFAULT 0,
        isFavorite INTEGER DEFAULT 0,
        isHidden INTEGER DEFAULT 0,

        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        deletedAt TEXT,

        FOREIGN KEY (courseId) REFERENCES courses(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE card_examples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cardId INTEGER NOT NULL,

        exampleText TEXT NOT NULL,
        pronunciation TEXT,
        meaning TEXT,

        createdAt TEXT NOT NULL,
        updatedAt TEXT,

        FOREIGN KEY (cardId) REFERENCES cards(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE course_tags (
        courseId INTEGER NOT NULL,
        tagId INTEGER NOT NULL,

        PRIMARY KEY (courseId, tagId),

        FOREIGN KEY (courseId) REFERENCES courses(id) ON DELETE CASCADE,
        FOREIGN KEY (tagId) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE review_states (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cardId INTEGER NOT NULL UNIQUE,

        level INTEGER DEFAULT 0,
        easeFactor REAL DEFAULT 2.5,
        intervalDays INTEGER DEFAULT 0,
        repetitionCount INTEGER DEFAULT 0,

        correctCount INTEGER DEFAULT 0,
        wrongCount INTEGER DEFAULT 0,

        lastReviewedAt TEXT,
        nextReviewAt TEXT,

        createdAt TEXT NOT NULL,
        updatedAt TEXT,

        FOREIGN KEY (cardId) REFERENCES cards(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId INTEGER NOT NULL,

        mode TEXT NOT NULL,
        totalCards INTEGER DEFAULT 0,
        correctCount INTEGER DEFAULT 0,
        wrongCount INTEGER DEFAULT 0,

        startedAt TEXT NOT NULL,
        endedAt TEXT,

        FOREIGN KEY (courseId) REFERENCES courses(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        cardId INTEGER NOT NULL,

        answerText TEXT,
        isCorrect INTEGER NOT NULL,
        responseTimeMs INTEGER,

        reviewedAt TEXT NOT NULL,

        FOREIGN KEY (sessionId) REFERENCES study_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (cardId) REFERENCES cards(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE import_exports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        type TEXT NOT NULL,
        fileName TEXT,
        filePath TEXT,
        format TEXT NOT NULL,

        courseId INTEGER,
        status TEXT NOT NULL,
        message TEXT,

        createdAt TEXT NOT NULL,

        FOREIGN KEY (courseId) REFERENCES courses(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    await _createIndexes(db);
    await _insertDefaultLanguages(db);
    await _insertDefaultSettings(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX idx_courses_languageCode ON courses(languageCode)',
    );

    await db.execute(
      'CREATE INDEX idx_cards_courseId ON cards(courseId)',
    );

    await db.execute(
      'CREATE INDEX idx_cards_term ON cards(term)',
    );

    await db.execute(
      'CREATE INDEX idx_cards_pronunciation ON cards(pronunciation)',
    );

    await db.execute(
      'CREATE INDEX idx_review_nextReviewAt ON review_states(nextReviewAt)',
    );

    await db.execute(
      'CREATE INDEX idx_study_sessions_courseId ON study_sessions(courseId)',
    );

    await db.execute(
      'CREATE INDEX idx_study_results_cardId ON study_results(cardId)',
    );
    await db.execute(
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_courses_title_unique ON courses(lower(trim(title))) WHERE deletedAt IS NULL',
    );
  }

  Future<void> _insertDefaultLanguages(Database db) async {
    final now = DateTime.now().toIso8601String();

    final languages = [
      {
        'name': 'Tiếng Trung Phồn thể',
        'nativeName': '繁體中文',
        'code': 'zh-TW',
        'ttsCode': 'zh-TW',
        'scriptType': 'traditional',
        'createdAt': now,
      },
      {
        'name': 'Tiếng Trung Giản thể',
        'nativeName': '简体中文',
        'code': 'zh-CN',
        'ttsCode': 'zh-CN',
        'scriptType': 'simplified',
        'createdAt': now,
      },
      {
        'name': 'Tiếng Anh',
        'nativeName': 'English',
        'code': 'en-US',
        'ttsCode': 'en-US',
        'scriptType': 'latin',
        'createdAt': now,
      },
      {
        'name': 'Tiếng Đức',
        'nativeName': 'Deutsch',
        'code': 'de-DE',
        'ttsCode': 'de-DE',
        'scriptType': 'latin',
        'createdAt': now,
      },
      {
        'name': 'Tiếng Nhật',
        'nativeName': '日本語',
        'code': 'ja-JP',
        'ttsCode': 'ja-JP',
        'scriptType': 'japanese',
        'createdAt': now,
      },
      {
        'name': 'Tiếng Hàn',
        'nativeName': '한국어',
        'code': 'ko-KR',
        'ttsCode': 'ko-KR',
        'scriptType': 'korean',
        'createdAt': now,
      },
      {
        'name': 'Tiếng Việt',
        'nativeName': 'Tiếng Việt',
        'code': 'vi-VN',
        'ttsCode': 'vi-VN',
        'scriptType': 'latin',
        'createdAt': now,
      },
    ];

    for (final language in languages) {
      await db.insert(
        'languages',
        language,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final now = DateTime.now().toIso8601String();

    final settings = {
      'defaultLanguageCode': 'zh-TW',
      'defaultInputFormat': 'auto',
      'defaultTermSeparator': 'tab',
      'defaultCardSeparator': 'newline',
      'autoShowPreview': 'false',
      'themeMode': 'light',
    };

    for (final entry in settings.entries) {
      await db.insert(
        'app_settings',
        {
          'key': entry.key,
          'value': entry.value,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) return;

    await db.close();
    _database = null;
  }

  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'list_card.db');

    print("DATABASE PATH: $path");
    await deleteDatabase(path);
    _database = null;
  }
}