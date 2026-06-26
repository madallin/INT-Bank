// ============================================================
// Event Publisher Port (Outbound Port — Driven Side)
// Hexagonal Architecture — Ports (Core Domain)
// ============================================================

/**
 * Generic event publisher port.
 * The infrastructure layer implements this with Kafka/KafkaJS.
 * The core domain never depends on Kafka directly.
 */
export abstract class EventPublisher {
  /**
   * Publish an event to a specific topic.
   * @param topic  Kafka topic name (e.g., 'transfer.initiated')
   * @param key    Partitioning key (e.g., transferId)
   * @param event  JSON-serializable payload
   */
  abstract publish<T extends Record<string, unknown>>(
    topic: string,
    key: string,
    event: T,
  ): Promise<void>;
}
