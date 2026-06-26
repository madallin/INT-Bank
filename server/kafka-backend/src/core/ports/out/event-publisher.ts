export abstract class EventPublisher
{
  abstract publish<T extends Record<string, unknown>>(
    topic: string,
    event: T,
  ): Promise<void>;
}
