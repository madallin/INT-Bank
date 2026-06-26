// ============================================================
// Outbound Port: EventPublisher
// Hexagonal Architecture — Core Domain Layer
// This port decouples the domain from any specific messaging
// system (Kafka, RabbitMQ, SQS, etc.). The infrastructure layer
// provides the concrete implementation.
// ============================================================

export abstract class EventPublisher {
  /**
   * Publish an event to the configured message broker.
   * @param topic  The topic/channel name (e.g., "transfer.initiated")
   * @param event  The event payload (must be serializable to JSON)
   */
  abstract publish<T extends Record<string, unknown>>(
    topic: string,
    event: T,
  ): Promise<void>;
}
