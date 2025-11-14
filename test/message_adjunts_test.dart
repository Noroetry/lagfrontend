import 'package:flutter_test/flutter_test.dart';
import 'package:lagfrontend/models/message_model.dart';
import 'package:lagfrontend/models/message_adjunt_model.dart';

void main() {
  group('Message with Adjunts', () {
    test('parses reward message with adjunts correctly', () {
      final json = {
        "id": 456,
        "title": "Recompensa de misión",
        "description":
            "La misión \"Maestro del Entrenamiento\" te ha otorgado las siguientes recompensas:",
        "questTitle": "Maestro del Entrenamiento",
        "type": "reward",
        "adjunts": [
          {
            "id": 3,
            "objectName": "Experiencia",
            "shortName": "EXP",
            "description": "Puntos de experiencia del jugador",
            "type": "experience",
            "quantity": 500,
          },
          {
            "id": 2,
            "objectName": "Moneda",
            "shortName": "COIN",
            "description": "Monedas del juego",
            "type": "coin",
            "quantity": 1000,
          },
          {
            "id": 1,
            "objectName": "Misión",
            "shortName": "QUEST",
            "description": "Asigna una misión especial al usuario",
            "type": "quest",
            "quantity": 1,
            "questAssignedTitle": "Desafío de Resistencia Extrema",
            "idQuestAssigned": 25,
          },
        ],
        "dateRead": null,
        "isRead": false,
        "createdAt": "2025-11-14T10:30:00.000Z",
      };

      final message = Message.fromJson(json);

      expect(message.id, 456);
      expect(message.title, "Recompensa de misión");
      expect(message.questTitle, "Maestro del Entrenamiento");
      expect(message.type, "reward");
      expect(message.isRead, false);

      expect(message.adjunts, isNotNull);
      expect(message.adjunts!.length, 3);

      // Check first adjunt (experience)
      final expAdjunt = message.adjunts![0];
      expect(expAdjunt.id, 3);
      expect(expAdjunt.objectName, "Experiencia");
      expect(expAdjunt.shortName, "EXP");
      expect(expAdjunt.type, "experience");
      expect(expAdjunt.quantity, 500);

      // Check second adjunt (coin)
      final coinAdjunt = message.adjunts![1];
      expect(coinAdjunt.id, 2);
      expect(coinAdjunt.objectName, "Moneda");
      expect(coinAdjunt.shortName, "COIN");
      expect(coinAdjunt.type, "coin");
      expect(coinAdjunt.quantity, 1000);

      // Check third adjunt (quest with assigned quest)
      final questAdjunt = message.adjunts![2];
      expect(questAdjunt.id, 1);
      expect(questAdjunt.objectName, "Misión");
      expect(questAdjunt.shortName, "QUEST");
      expect(questAdjunt.type, "quest");
      expect(questAdjunt.quantity, 1);
      expect(questAdjunt.questAssignedTitle, "Desafío de Resistencia Extrema");
      expect(questAdjunt.idQuestAssigned, 25);
    });

    test('parses penalty message with negative adjunts correctly', () {
      final json = {
        "id": 124,
        "title": "Penalización de misión",
        "description":
            "La misión \"Meditación\" ha expirado y se aplicaron las siguientes penalizaciones:",
        "questTitle": "Meditación",
        "type": "penalty",
        "adjunts": [
          {
            "id": 3,
            "objectName": "Experiencia",
            "shortName": "EXP",
            "description": "Puntos de experiencia del jugador",
            "type": "experience",
            "quantity": -20,
          },
        ],
        "dateRead": null,
        "isRead": false,
        "createdAt": "2025-11-13T23:00:00.000Z",
      };

      final message = Message.fromJson(json);

      expect(message.id, 124);
      expect(message.title, "Penalización de misión");
      expect(message.questTitle, "Meditación");
      expect(message.type, "penalty");
      expect(message.isRead, false);

      expect(message.adjunts, isNotNull);
      expect(message.adjunts!.length, 1);

      final expAdjunt = message.adjunts![0];
      expect(expAdjunt.quantity, -20);
    });

    test('parses info message without adjunts correctly', () {
      final json = {
        "id": 1,
        "title": "Bienvenido al Sistema",
        "description":
            "Tu camino empieza ahora, no mires hacia delante, ni hacia atrás, céntrate en el ahora.",
        "questTitle": null,
        "type": "info",
        "adjunts": null,
        "dateRead": null,
        "isRead": false,
        "createdAt": "2025-11-14T10:00:00.000Z",
      };

      final message = Message.fromJson(json);

      expect(message.id, 1);
      expect(message.title, "Bienvenido al Sistema");
      expect(
        message.description,
        "Tu camino empieza ahora, no mires hacia delante, ni hacia atrás, céntrate en el ahora.",
      );
      expect(message.questTitle, isNull);
      expect(message.type, "info");
      expect(message.adjunts, isNull);
      expect(message.isRead, false);
    });

    test('serializes message with adjunts back to JSON correctly', () {
      final message = Message(
        id: 456,
        title: "Test Message",
        description: "Test Description",
        questTitle: "Test Quest",
        type: "reward",
        adjunts: [
          const MessageAdjunt(
            id: 1,
            objectName: "Experiencia",
            shortName: "EXP",
            description: "Puntos de experiencia",
            type: "experience",
            quantity: 100,
          ),
        ],
        isRead: false,
        createdAt: "2025-11-14T10:00:00.000Z",
      );

      final json = message.toJson();

      expect(json['id'], 456);
      expect(json['questTitle'], "Test Quest");
      expect(json['type'], "reward");
      expect(json['adjunts'], isNotNull);
      expect(json['adjunts'], isList);
      expect((json['adjunts'] as List).length, 1);
    });
  });
}
