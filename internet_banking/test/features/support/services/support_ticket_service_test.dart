import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/support/services/support_ticket_service.dart';

class FakeSupportTicketApi implements SupportTicketApi {
  final Map<String, SupportTicket> store = <String, SupportTicket>{};
  int createCalls = 0;
  int saveCalls = 0;
  int getCalls = 0;
  List<String> persistedIds = <String>[];

  @override
  Future<SupportTicket> createTicket(SupportTicket ticket) async {
    createCalls += 1;
    store[ticket.ticketId] = ticket;
    persistedIds.add(ticket.ticketId);
    return ticket;
  }

  @override
  Future<SupportTicket> saveTicket(SupportTicket ticket) async {
    saveCalls += 1;
    store[ticket.ticketId] = ticket;
    persistedIds.add(ticket.ticketId);
    return ticket;
  }

  @override
  Future<SupportTicket?> getTicket(String ticketId) async {
    getCalls += 1;
    return store[ticketId];
  }
}

class IdSequence {
  IdSequence([this.prefix = 'id']);

  final String prefix;
  int _value = 0;

  String next() {
    _value += 1;
    return '$prefix-$_value';
  }
}

DateTime Function() fixedClock(DateTime instant) => () => instant;

DateTime Function() advancingClock(DateTime start) {
  DateTime current = start;
  return () {
    final DateTime value = current;
    current = current.add(const Duration(minutes: 1));
    return value;
  };
}

final DateTime baseTime = DateTime.utc(2026, 5, 1, 9, 0, 0);

SupportTicketService buildService({
  FakeSupportTicketApi? api,
  DateTime Function()? clock,
  String prefix = 'TKT',
}) {
  return SupportTicketService(
    api: api ?? FakeSupportTicketApi(),
    clock: clock ?? fixedClock(baseTime),
    idGenerator: IdSequence(prefix).next,
  );
}

void main() {
  group('createTicket', () {
    test('creates an open normal ticket with one customer message', () async {
      final FakeSupportTicketApi api = FakeSupportTicketApi();
      final SupportTicketService service = buildService(api: api);

      final SupportTicket ticket = await service.createTicket(
        subject: 'Card declined',
        body: 'My card was declined online.',
      );

      expect(ticket.status, TicketStatus.open);
      expect(ticket.priority, TicketPriority.normal);
      expect(ticket.subject, 'Card declined');
      expect(ticket.messages, hasLength(1));
      expect(ticket.messages.first.sequence, 1);
      expect(ticket.messages.first.authorRole, ChatAuthorRole.customer);
      expect(ticket.messages.first.body, 'My card was declined online.');
      expect(ticket.createdAt, baseTime);
      expect(ticket.updatedAt, baseTime);
      expect(ticket.assignedAgentId, isNull);
      expect(ticket.requiresHumanHandover, isFalse);
      expect(api.createCalls, 1);
    });

    test('trims subject and body', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: '  Overdraft fee  ',
        body: '  There is a fee I do not recognize.  ',
      );
      expect(ticket.subject, 'Overdraft fee');
      expect(ticket.messages.first.body, 'There is a fee I do not recognize.');
    });

    test('injects context as a leading system message', () async {
      final SupportTicketService service = buildService();
      const TicketContext context = TicketContext(
        deviceOs: 'Android 15',
        appVersion: '1.4.2',
        referencedTransactionId: 'TX-998877',
      );

      final SupportTicket ticket = await service.createTicket(
        subject: 'Dispute transaction',
        body: 'I did not authorize this payment.',
        context: context,
      );

      expect(ticket.context, context);
      expect(ticket.messages, hasLength(2));
      expect(ticket.messages[0].authorRole, ChatAuthorRole.system);
      expect(ticket.messages[0].sequence, 1);
      expect(ticket.messages[0].body, contains('Android 15'));
      expect(ticket.messages[0].body, contains('1.4.2'));
      expect(ticket.messages[0].body, contains('TX-998877'));
      expect(ticket.messages[1].authorRole, ChatAuthorRole.customer);
      expect(ticket.messages[1].sequence, 2);
    });

    test('includes metadata entries in the context summary', () async {
      final SupportTicketService service = buildService();
      const TicketContext context = TicketContext(
        deviceOs: 'iOS 18',
        metadata: <String, String>{'locale': 'ro-RO', 'network': 'wifi'},
      );

      final SupportTicket ticket = await service.createTicket(
        subject: 'Login issue',
        body: 'I cannot log in.',
        context: context,
      );

      final String summary = ticket.messages.first.body;
      expect(summary, contains('locale: ro-RO'));
      expect(summary, contains('network: wifi'));
      expect(summary, isNot(contains('Referenced transaction')));
    });

    test('urgent priority forces requiresHumanHandover', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Fraud',
        body: 'Unrecognized charge.',
        priority: TicketPriority.urgent,
      );
      expect(ticket.priority, TicketPriority.urgent);
      expect(ticket.requiresHumanHandover, isTrue);
    });

    test('explicit handover flag is honored on a low priority ticket',
        () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Account update',
        body: 'Please update my phone number.',
        priority: TicketPriority.low,
        requiresHumanHandover: true,
      );
      expect(ticket.requiresHumanHandover, isTrue);
      expect(ticket.priority, TicketPriority.low);
    });

    test('rejects an empty subject and does not persist', () async {
      final FakeSupportTicketApi api = FakeSupportTicketApi();
      final SupportTicketService service = buildService(api: api);
      expect(
        () => service.createTicket(subject: '   ', body: 'body'),
        throwsA(isA<TicketValidationException>()),
      );
      expect(api.createCalls, 0);
    });

    test('rejects an empty body and does not persist', () async {
      final FakeSupportTicketApi api = FakeSupportTicketApi();
      final SupportTicketService service = buildService(api: api);
      expect(
        () => service.createTicket(subject: 'subject', body: '   '),
        throwsA(isA<TicketValidationException>()),
      );
      expect(api.createCalls, 0);
    });

    test('rejects an empty customer identifier', () async {
      final SupportTicketService service = buildService();
      expect(
        () => service.createTicket(
          subject: 'subject',
          body: 'body',
          customerId: ' ',
        ),
        throwsA(isA<TicketValidationException>()),
      );
    });
  });

  group('message sequencing', () {
    test('assigns strictly increasing sequence numbers', () async {
      final SupportTicketService service = buildService(
        clock: advancingClock(baseTime),
      );
      SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'First message.',
      );
      ticket = await service.addMessage(
        ticket,
        body: 'Second message.',
        authorRole: ChatAuthorRole.customer,
        authorId: 'customer',
      );
      ticket = await service.addMessage(
        ticket,
        body: 'Third message.',
        authorRole: ChatAuthorRole.agent,
        authorId: 'agent-1',
      );

      expect(
        ticket.messages.map((ChatMessage m) => m.sequence).toList(),
        <int>[1, 2, 3],
      );
      for (int i = 1; i < ticket.messages.length; i++) {
        expect(
          ticket.messages[i].sequence,
          greaterThan(ticket.messages[i - 1].sequence),
        );
        expect(
          ticket.messages[i].sentAt.isAfter(ticket.messages[i - 1].sentAt),
          isTrue,
        );
      }
      expect(ticket.nextSequence, 4);
    });

    test('message identifiers come from the injected id generator', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'IDs',
        body: 'body',
      );
      final SupportTicket updated = await service.addMessage(
        ticket,
        body: 'reply',
        authorRole: ChatAuthorRole.customer,
        authorId: 'customer',
      );
      expect(updated.messages[0].messageId, 'TKT-2');
      expect(updated.messages[1].messageId, 'TKT-3');
      expect(updated.ticketId, 'TKT-1');
    });

    test('rejects an empty message body', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'First message.',
      );
      expect(
        () => service.addMessage(
          ticket,
          body: '   ',
          authorRole: ChatAuthorRole.customer,
          authorId: 'customer',
        ),
        throwsA(isA<TicketValidationException>()),
      );
    });

    test('rejects adding a message to a resolved ticket', () async {
      final SupportTicketService service = buildService();
      SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'First message.',
      );
      ticket = await service.resolve(ticket);
      expect(
        () => service.addMessage(
          ticket,
          body: 'Too late.',
          authorRole: ChatAuthorRole.customer,
          authorId: 'customer',
        ),
        throwsA(isA<TicketValidationException>()),
      );
    });

    test('persists each appended message through the api', () async {
      final FakeSupportTicketApi api = FakeSupportTicketApi();
      final SupportTicketService service = buildService(api: api);
      SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'First message.',
      );
      ticket = await service.addMessage(
        ticket,
        body: 'Second message.',
        authorRole: ChatAuthorRole.customer,
        authorId: 'customer',
      );
      expect(api.saveCalls, 1);
      expect(api.store[ticket.ticketId]!.messages, hasLength(2));
    });
  });

  group('status transitions', () {
    test('canTransition allows the legal graph', () {
      expect(
        SupportTicketService.canTransition(
          TicketStatus.open,
          TicketStatus.agentAssigned,
        ),
        isTrue,
      );
      expect(
        SupportTicketService.canTransition(
          TicketStatus.open,
          TicketStatus.resolved,
        ),
        isTrue,
      );
      expect(
        SupportTicketService.canTransition(
          TicketStatus.agentAssigned,
          TicketStatus.waitingForCustomer,
        ),
        isTrue,
      );
      expect(
        SupportTicketService.canTransition(
          TicketStatus.waitingForCustomer,
          TicketStatus.agentAssigned,
        ),
        isTrue,
      );
      expect(
        SupportTicketService.canTransition(
          TicketStatus.agentAssigned,
          TicketStatus.resolved,
        ),
        isTrue,
      );
    });

    test('canTransition rejects illegal and self transitions', () {
      expect(
        SupportTicketService.canTransition(
          TicketStatus.open,
          TicketStatus.waitingForCustomer,
        ),
        isFalse,
      );
      expect(
        SupportTicketService.canTransition(
          TicketStatus.resolved,
          TicketStatus.open,
        ),
        isFalse,
      );
      expect(
        SupportTicketService.canTransition(
          TicketStatus.open,
          TicketStatus.open,
        ),
        isFalse,
      );
    });

    test('transition mutates status and updatedAt deterministically', () async {
      final SupportTicketService service = buildService(
        clock: advancingClock(baseTime),
      );
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      final SupportTicket assigned =
          service.transition(ticket, TicketStatus.agentAssigned);
      expect(assigned.status, TicketStatus.agentAssigned);
      expect(assigned.updatedAt.isAfter(ticket.updatedAt), isTrue);
      expect(ticket.status, TicketStatus.open);
    });

    test('illegal transition throws a typed exception', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      expect(
        () => service.transition(ticket, TicketStatus.waitingForCustomer),
        throwsA(isA<InvalidTicketTransitionException>()),
      );
    });

    test('resolved tickets cannot transition anywhere', () async {
      final SupportTicketService service = buildService();
      SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      ticket = await service.resolve(ticket);
      expect(
        () => service.transition(ticket, TicketStatus.open),
        throwsA(isA<InvalidTicketTransitionException>()),
      );
    });

    test('resolve clears the handover flag and persists', () async {
      final FakeSupportTicketApi api = FakeSupportTicketApi();
      final SupportTicketService service = buildService(api: api);
      SupportTicket ticket = await service.createTicket(
        subject: 'Fraud',
        body: 'Unrecognized charge.',
        priority: TicketPriority.urgent,
      );
      expect(ticket.requiresHumanHandover, isTrue);
      ticket = await service.resolve(ticket);
      expect(ticket.status, TicketStatus.resolved);
      expect(ticket.requiresHumanHandover, isFalse);
      expect(ticket.isResolved, isTrue);
      expect(api.saveCalls, 1);
    });

    test('changeStatus persists a legal transition', () async {
      final FakeSupportTicketApi api = FakeSupportTicketApi();
      final SupportTicketService service = buildService(api: api);
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      final SupportTicket assigned = await service.changeStatus(
        ticket,
        TicketStatus.agentAssigned,
      );
      expect(assigned.status, TicketStatus.agentAssigned);
      expect(api.store[ticket.ticketId]!.status, TicketStatus.agentAssigned);
    });

    test('changeStatus rejects an illegal transition', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      expect(
        () => service.changeStatus(ticket, TicketStatus.waitingForCustomer),
        throwsA(isA<InvalidTicketTransitionException>()),
      );
    });
  });

  group('agent handover', () {
    test('addAgentMessage assigns the agent and moves to agentAssigned',
        () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      final SupportTicket updated = await service.addAgentMessage(
        ticket,
        agentId: 'agent-42',
        body: 'Hello, I will help you.',
      );
      expect(updated.status, TicketStatus.agentAssigned);
      expect(updated.assignedAgentId, 'agent-42');
      expect(updated.messages.last.authorRole, ChatAuthorRole.agent);
      expect(updated.messages.last.authorId, 'agent-42');
    });

    test('assignAgent records handover flags and a system message', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      final SupportTicket assigned = await service.assignAgent(
        ticket,
        agentId: 'agent-7',
        requiresHumanHandover: true,
      );
      expect(assigned.status, TicketStatus.agentAssigned);
      expect(assigned.assignedAgentId, 'agent-7');
      expect(assigned.requiresHumanHandover, isTrue);
      expect(assigned.hasAssignedAgent, isTrue);
      expect(assigned.messages.last.authorRole, ChatAuthorRole.system);
      expect(assigned.messages.last.body, contains('agent-7'));
    });

    test('assignAgent is idempotent for an already assigned ticket', () async {
      final SupportTicketService service = buildService();
      SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      ticket = await service.assignAgent(ticket, agentId: 'agent-1');
      final SupportTicket reassigned =
          await service.assignAgent(ticket, agentId: 'agent-2');
      expect(reassigned.status, TicketStatus.agentAssigned);
      expect(reassigned.assignedAgentId, 'agent-2');
      expect(reassigned.requiresHumanHandover, isFalse);
    });

    test('assignAgent rejects an empty agent id', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      expect(
        () => service.assignAgent(ticket, agentId: '  '),
        throwsA(isA<TicketValidationException>()),
      );
    });

    test('requestHumanHandover flags the ticket without changing status',
        () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      final SupportTicket flagged = await service.requestHumanHandover(
        ticket,
        note: 'Please escalate.',
      );
      expect(flagged.requiresHumanHandover, isTrue);
      expect(flagged.status, TicketStatus.open);
      expect(flagged.messages.last.authorRole, ChatAuthorRole.system);
      expect(flagged.messages.last.body, contains('Please escalate.'));
    });

    test('addCustomerMessage from waitingForCustomer reopens for the agent',
        () async {
      final SupportTicketService service = buildService();
      SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      ticket = await service.assignAgent(ticket, agentId: 'agent-1');
      ticket = await service.markWaitingForCustomer(ticket);
      expect(ticket.status, TicketStatus.waitingForCustomer);

      ticket = await service.addCustomerMessage(
        ticket,
        body: 'Here is the document you asked for.',
      );
      expect(ticket.status, TicketStatus.agentAssigned);
      expect(ticket.assignedAgentId, 'agent-1');
    });
  });

  group('TicketContext', () {
    test('reports emptiness and referenced transaction', () {
      const TicketContext empty = TicketContext();
      expect(empty.isEmpty, isTrue);
      expect(empty.hasReferencedTransaction, isFalse);

      const TicketContext withTxn = TicketContext(
        referencedTransactionId: 'TX-1',
      );
      expect(withTxn.isEmpty, isFalse);
      expect(withTxn.hasReferencedTransaction, isTrue);
    });

    test('copyWith replaces only supplied fields', () {
      const TicketContext base = TicketContext(
        deviceOs: 'Android',
        appVersion: '1.0.0',
      );
      final TicketContext updated = base.copyWith(appVersion: '2.0.0');
      expect(updated.deviceOs, 'Android');
      expect(updated.appVersion, '2.0.0');
    });

    test('supports value equality including metadata', () {
      const TicketContext a = TicketContext(
        deviceOs: 'Android',
        metadata: <String, String>{'locale': 'ro-RO'},
      );
      const TicketContext b = TicketContext(
        deviceOs: 'Android',
        metadata: <String, String>{'locale': 'ro-RO'},
      );
      const TicketContext c = TicketContext(
        deviceOs: 'Android',
        metadata: <String, String>{'locale': 'en-US'},
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('SupportTicket model', () {
    test('copyWith and equality compare every field', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      final SupportTicket same = ticket.copyWith();
      final SupportTicket changed = ticket.copyWith(subject: 'Other');
      expect(same, equals(ticket));
      expect(same.hashCode, ticket.hashCode);
      expect(changed, isNot(equals(ticket)));
    });

    test('exposes the last message and next sequence', () async {
      final SupportTicketService service = buildService();
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      expect(ticket.lastMessage, isNotNull);
      expect(ticket.lastMessage!.sequence, 1);
      expect(ticket.nextSequence, 2);
      expect(ticket.toString(), contains('Question'));
    });

    test('getTicket delegates to the api', () async {
      final FakeSupportTicketApi api = FakeSupportTicketApi();
      final SupportTicketService service = buildService(api: api);
      final SupportTicket ticket = await service.createTicket(
        subject: 'Question',
        body: 'body',
      );
      final SupportTicket? loaded = await service.getTicket(ticket.ticketId);
      expect(loaded, equals(ticket));
      expect(api.getCalls, 1);
      expect(await service.getTicket('missing'), isNull);
    });

    test('buildContextSummary renders every populated field', () {
      final SupportTicketService service = buildService();
      const TicketContext context = TicketContext(
        deviceOs: 'Windows 11',
        appVersion: '3.1.0',
        referencedTransactionId: 'TX-55',
        metadata: <String, String>{'channel': 'mobile'},
      );
      final String summary = service.buildContextSummary(context);
      expect(summary, contains('Device OS: Windows 11'));
      expect(summary, contains('App version: 3.1.0'));
      expect(summary, contains('Referenced transaction: TX-55'));
      expect(summary, contains('channel: mobile'));
    });
  });
}
