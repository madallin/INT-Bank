enum TicketPriority { low, normal, urgent }

enum TicketStatus { open, agentAssigned, waitingForCustomer, resolved }

enum ChatAuthorRole { customer, agent, system }

class TicketValidationException implements Exception {
  final String message;

  const TicketValidationException(this.message);

  @override
  String toString() => 'TicketValidationException: $message';
}

class InvalidTicketTransitionException implements Exception {
  final String ticketId;
  final TicketStatus from;
  final TicketStatus to;

  const InvalidTicketTransitionException({
    required this.ticketId,
    required this.from,
    required this.to,
  });

  @override
  String toString() =>
      'InvalidTicketTransitionException: cannot move ticket $ticketId '
      'from $from to $to';
}

class TicketContext {
  final String deviceOs;
  final String appVersion;
  final String? referencedTransactionId;
  final Map<String, String> metadata;

  const TicketContext({
    this.deviceOs = '',
    this.appVersion = '',
    this.referencedTransactionId,
    this.metadata = const <String, String>{},
  });

  bool get hasReferencedTransaction =>
      referencedTransactionId != null && referencedTransactionId!.isNotEmpty;

  bool get isEmpty =>
      deviceOs.isEmpty &&
      appVersion.isEmpty &&
      !hasReferencedTransaction &&
      metadata.isEmpty;

  TicketContext copyWith({
    String? deviceOs,
    String? appVersion,
    String? referencedTransactionId,
    Map<String, String>? metadata,
  }) {
    return TicketContext(
      deviceOs: deviceOs ?? this.deviceOs,
      appVersion: appVersion ?? this.appVersion,
      referencedTransactionId:
          referencedTransactionId ?? this.referencedTransactionId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TicketContext &&
        other.deviceOs == deviceOs &&
        other.appVersion == appVersion &&
        other.referencedTransactionId == referencedTransactionId &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        deviceOs,
        appVersion,
        referencedTransactionId,
        Object.hashAll(metadata.keys),
        Object.hashAll(metadata.values),
      );

  @override
  String toString() =>
      'TicketContext(deviceOs: $deviceOs, appVersion: $appVersion, '
      'referencedTransactionId: $referencedTransactionId, '
      'metadata: $metadata)';
}

class ChatMessage {
  final String messageId;
  final String ticketId;
  final int sequence;
  final ChatAuthorRole authorRole;
  final String authorId;
  final String body;
  final DateTime sentAt;

  const ChatMessage({
    required this.messageId,
    required this.ticketId,
    required this.sequence,
    required this.authorRole,
    required this.authorId,
    required this.body,
    required this.sentAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ChatMessage &&
        other.messageId == messageId &&
        other.ticketId == ticketId &&
        other.sequence == sequence &&
        other.authorRole == authorRole &&
        other.authorId == authorId &&
        other.body == body &&
        other.sentAt == sentAt;
  }

  @override
  int get hashCode => Object.hash(
        messageId,
        ticketId,
        sequence,
        authorRole,
        authorId,
        body,
        sentAt,
      );

  @override
  String toString() =>
      'ChatMessage(messageId: $messageId, ticketId: $ticketId, '
      'sequence: $sequence, authorRole: $authorRole, authorId: $authorId, '
      'body: $body, sentAt: $sentAt)';
}

class SupportTicket {
  final String ticketId;
  final String subject;
  final TicketPriority priority;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final String? assignedAgentId;
  final bool requiresHumanHandover;
  final TicketContext context;

  const SupportTicket({
    required this.ticketId,
    required this.subject,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const <ChatMessage>[],
    this.assignedAgentId,
    this.requiresHumanHandover = false,
    this.context = const TicketContext(),
  });

  int get nextSequence => messages.length + 1;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  bool get isResolved => status == TicketStatus.resolved;

  bool get hasAssignedAgent =>
      assignedAgentId != null && assignedAgentId!.isNotEmpty;

  SupportTicket copyWith({
    String? ticketId,
    String? subject,
    TicketPriority? priority,
    TicketStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    String? assignedAgentId,
    bool? requiresHumanHandover,
    TicketContext? context,
  }) {
    return SupportTicket(
      ticketId: ticketId ?? this.ticketId,
      subject: subject ?? this.subject,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      requiresHumanHandover:
          requiresHumanHandover ?? this.requiresHumanHandover,
      context: context ?? this.context,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SupportTicket &&
        other.ticketId == ticketId &&
        other.subject == subject &&
        other.priority == priority &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        _listEquals(other.messages, messages) &&
        other.assignedAgentId == assignedAgentId &&
        other.requiresHumanHandover == requiresHumanHandover &&
        other.context == context;
  }

  @override
  int get hashCode => Object.hash(
        ticketId,
        subject,
        priority,
        status,
        createdAt,
        updatedAt,
        Object.hashAll(messages),
        assignedAgentId,
        requiresHumanHandover,
        context,
      );

  @override
  String toString() =>
      'SupportTicket(ticketId: $ticketId, subject: $subject, '
      'priority: $priority, status: $status, messages: ${messages.length}, '
      'assignedAgentId: $assignedAgentId, '
      'requiresHumanHandover: $requiresHumanHandover, context: $context)';
}

abstract class SupportTicketApi {
  Future<SupportTicket> createTicket(SupportTicket ticket);

  Future<SupportTicket> saveTicket(SupportTicket ticket);

  Future<SupportTicket?> getTicket(String ticketId);
}

class SupportTicketService {
  final SupportTicketApi api;
  final DateTime Function() clock;
  final String Function() idGenerator;

  static int _fallbackCounter = 0;

  SupportTicketService({
    required this.api,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : clock = clock ?? DateTime.now,
        idGenerator = idGenerator ?? _fallbackIdGenerator;

  static String _fallbackIdGenerator() {
    _fallbackCounter += 1;
    return 'TKT-${_fallbackCounter.toString().padLeft(6, '0')}';
  }

  static bool canTransition(TicketStatus from, TicketStatus to) {
    switch (from) {
      case TicketStatus.open:
        return to == TicketStatus.agentAssigned ||
            to == TicketStatus.resolved;
      case TicketStatus.agentAssigned:
        return to == TicketStatus.waitingForCustomer ||
            to == TicketStatus.resolved;
      case TicketStatus.waitingForCustomer:
        return to == TicketStatus.agentAssigned ||
            to == TicketStatus.resolved;
      case TicketStatus.resolved:
        return false;
    }
  }

  String buildContextSummary(TicketContext context) {
    final List<String> parts = <String>[];
    if (context.deviceOs.isNotEmpty) {
      parts.add('Device OS: ${context.deviceOs}');
    }
    if (context.appVersion.isNotEmpty) {
      parts.add('App version: ${context.appVersion}');
    }
    if (context.hasReferencedTransaction) {
      parts.add('Referenced transaction: ${context.referencedTransactionId}');
    }
    for (final MapEntry<String, String> entry in context.metadata.entries) {
      parts.add('${entry.key}: ${entry.value}');
    }
    return 'Context: ${parts.join('; ')}';
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String body,
    TicketPriority priority = TicketPriority.normal,
    TicketContext context = const TicketContext(),
    String customerId = 'customer',
    bool requiresHumanHandover = false,
  }) {
    final String trimmedSubject = subject.trim();
    final String trimmedBody = body.trim();
    if (trimmedSubject.isEmpty) {
      throw const TicketValidationException('subject must not be empty');
    }
    if (trimmedBody.isEmpty) {
      throw const TicketValidationException('body must not be empty');
    }
    final String trimmedCustomer = customerId.trim();
    if (trimmedCustomer.isEmpty) {
      throw const TicketValidationException('customerId must not be empty');
    }

    final DateTime now = clock();
    final String ticketId = idGenerator();
    final bool handoverRequired =
        requiresHumanHandover || priority == TicketPriority.urgent;

    final List<ChatMessage> messages = <ChatMessage>[];
    if (!context.isEmpty) {
      messages.add(
        ChatMessage(
          messageId: idGenerator(),
          ticketId: ticketId,
          sequence: 1,
          authorRole: ChatAuthorRole.system,
          authorId: 'system',
          body: buildContextSummary(context),
          sentAt: now,
        ),
      );
    }
    messages.add(
      ChatMessage(
        messageId: idGenerator(),
        ticketId: ticketId,
        sequence: messages.length + 1,
        authorRole: ChatAuthorRole.customer,
        authorId: trimmedCustomer,
        body: trimmedBody,
        sentAt: now,
      ),
    );

    final SupportTicket ticket = SupportTicket(
      ticketId: ticketId,
      subject: trimmedSubject,
      priority: priority,
      status: TicketStatus.open,
      createdAt: now,
      updatedAt: now,
      messages: messages,
      assignedAgentId: null,
      requiresHumanHandover: handoverRequired,
      context: context,
    );
    return api.createTicket(ticket);
  }

  SupportTicket transition(SupportTicket ticket, TicketStatus next) {
    if (!canTransition(ticket.status, next)) {
      throw InvalidTicketTransitionException(
        ticketId: ticket.ticketId,
        from: ticket.status,
        to: next,
      );
    }
    final SupportTicket updated = ticket.copyWith(
      status: next,
      updatedAt: clock(),
    );
    if (next == TicketStatus.resolved) {
      return updated.copyWith(requiresHumanHandover: false);
    }
    return updated;
  }

  Future<SupportTicket> changeStatus(
    SupportTicket ticket,
    TicketStatus next,
  ) {
    final SupportTicket updated = transition(ticket, next);
    return api.saveTicket(updated);
  }

  Future<SupportTicket> resolve(SupportTicket ticket) =>
      changeStatus(ticket, TicketStatus.resolved);

  Future<SupportTicket> addMessage(
    SupportTicket ticket, {
    required String body,
    required ChatAuthorRole authorRole,
    required String authorId,
  }) {
    final String trimmedBody = body.trim();
    final String trimmedAuthor = authorId.trim();
    if (trimmedBody.isEmpty) {
      throw const TicketValidationException('message body must not be empty');
    }
    if (trimmedAuthor.isEmpty) {
      throw const TicketValidationException('authorId must not be empty');
    }
    if (ticket.status == TicketStatus.resolved) {
      throw TicketValidationException(
        'cannot add a message to resolved ticket ${ticket.ticketId}',
      );
    }

    final DateTime now = clock();
    final ChatMessage message = ChatMessage(
      messageId: idGenerator(),
      ticketId: ticket.ticketId,
      sequence: ticket.nextSequence,
      authorRole: authorRole,
      authorId: trimmedAuthor,
      body: trimmedBody,
      sentAt: now,
    );
    final List<ChatMessage> updatedMessages = <ChatMessage>[
      ...ticket.messages,
      message,
    ];
    final SupportTicket updated = ticket.copyWith(
      messages: updatedMessages,
      updatedAt: now,
    );
    return api.saveTicket(updated);
  }

  Future<SupportTicket> addCustomerMessage(
    SupportTicket ticket, {
    required String body,
    String customerId = 'customer',
  }) {
    SupportTicket working = ticket;
    if (working.status == TicketStatus.waitingForCustomer) {
      working = transition(working, TicketStatus.agentAssigned);
    }
    return addMessage(
      working,
      body: body,
      authorRole: ChatAuthorRole.customer,
      authorId: customerId,
    );
  }

  Future<SupportTicket> addAgentMessage(
    SupportTicket ticket, {
    required String agentId,
    required String body,
  }) {
    final String trimmedAgent = agentId.trim();
    if (trimmedAgent.isEmpty) {
      throw const TicketValidationException('agentId must not be empty');
    }
    SupportTicket working = ticket;
    if (working.status == TicketStatus.open ||
        working.status == TicketStatus.waitingForCustomer) {
      working = transition(working, TicketStatus.agentAssigned);
    }
    if (working.assignedAgentId != trimmedAgent) {
      working = working.copyWith(assignedAgentId: trimmedAgent);
    }
    return addMessage(
      working,
      body: body,
      authorRole: ChatAuthorRole.agent,
      authorId: trimmedAgent,
    );
  }

  Future<SupportTicket> assignAgent(
    SupportTicket ticket, {
    required String agentId,
    bool requiresHumanHandover = false,
  }) {
    final String trimmedAgent = agentId.trim();
    if (trimmedAgent.isEmpty) {
      throw const TicketValidationException('agentId must not be empty');
    }
    SupportTicket assigned;
    if (ticket.status == TicketStatus.agentAssigned) {
      assigned = ticket.copyWith(
        assignedAgentId: trimmedAgent,
        requiresHumanHandover: requiresHumanHandover,
        updatedAt: clock(),
      );
    } else {
      assigned = transition(ticket, TicketStatus.agentAssigned).copyWith(
        assignedAgentId: trimmedAgent,
        requiresHumanHandover: requiresHumanHandover,
      );
    }
    return addMessage(
      assigned,
      body: 'Agent $trimmedAgent assigned to ticket ${ticket.ticketId}.',
      authorRole: ChatAuthorRole.system,
      authorId: 'system',
    );
  }

  Future<SupportTicket> requestHumanHandover(
    SupportTicket ticket, {
    String? note,
  }) {
    final SupportTicket flagged = ticket.copyWith(
      requiresHumanHandover: true,
      updatedAt: clock(),
    );
    final String trimmedNote = note?.trim() ?? '';
    final String body = trimmedNote.isEmpty
        ? 'Customer requested a human agent.'
        : 'Customer requested a human agent: $trimmedNote';
    return addMessage(
      flagged,
      body: body,
      authorRole: ChatAuthorRole.system,
      authorId: 'system',
    );
  }

  Future<SupportTicket> markWaitingForCustomer(SupportTicket ticket) =>
      changeStatus(ticket, TicketStatus.waitingForCustomer);

  Future<SupportTicket?> getTicket(String ticketId) => api.getTicket(ticketId);
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final MapEntry<String, String> entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

bool _listEquals(List<ChatMessage> a, List<ChatMessage> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
