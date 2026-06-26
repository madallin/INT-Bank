export abstract class EventPublisher
{
  abstract publish<T extends Record<string, unknown>>(
    topic: string,
    key: string,
    event: T,
  ): Promise<void>;
}
