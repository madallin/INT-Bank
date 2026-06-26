"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var KafkaConsumerAdapter_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.KafkaConsumerAdapter = void 0;
const common_1 = require("@nestjs/common");
const kafkajs_1 = require("kafkajs");
const process_transfer_use_case_1 = require("../../../../../application/use-cases/process-transfer.use-case");
let KafkaConsumerAdapter = KafkaConsumerAdapter_1 = class KafkaConsumerAdapter {
    constructor(processTransferUseCase) {
        this.processTransferUseCase = processTransferUseCase;
        this.logger = new common_1.Logger(KafkaConsumerAdapter_1.name);
        const brokers = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
        this.kafka = new kafkajs_1.Kafka({
            clientId: 'banking-nestjs-consumer',
            brokers,
            logLevel: kafkajs_1.logLevel.INFO,
            retry: {
                initialRetryTime: 300,
                retries: 10,
            },
        });
        this.consumer = this.kafka.consumer({
            groupId: process.env.KAFKA_CONSUMER_GROUP_ID || 'banking-transfer-group',
            sessionTimeout: 30000,
            heartbeatInterval: 3000,
            maxInFlightRequests: 1,
        });
    }
    async onModuleInit() {
        try {
            await this.consumer.connect();
            this.logger.log('Kafka consumer connected');
            await this.consumer.subscribe({
                topic: 'transfer.initiated',
                fromBeginning: false,
            });
            await this.consumer.run({
                autoCommit: false,
                eachMessage: async (payload) => {
                    await this.handleMessage(payload);
                },
            });
            this.logger.log('Kafka consumer subscribed to "transfer.initiated" and running');
        }
        catch (error) {
            this.logger.error('Failed to start Kafka consumer', error);
        }
    }
    async onModuleDestroy() {
        try {
            await this.consumer.disconnect();
            this.logger.log('Kafka consumer disconnected');
        }
        catch (error) {
            this.logger.warn('Error disconnecting Kafka consumer', error);
        }
    }
    async handleMessage(payload) {
        const { topic, partition, message } = payload;
        const key = message.key?.toString() ?? 'unknown';
        const rawValue = message.value?.toString();
        if (!rawValue) {
            this.logger.warn(`Empty message received on "${topic}" [${partition}] key=${key}`);
            await this.commitOffset(payload);
            return;
        }
        this.logger.log(`Received message: topic="${topic}" [${partition}] offset=${message.offset} key=${key}`);
        try {
            const event = JSON.parse(rawValue);
            if (event.eventType !== 'transfer.initiated' || !event.transferId) {
                throw new Error(`Invalid event structure: ${rawValue.slice(0, 200)}`);
            }
            await this.processTransferUseCase.execute(event);
            await this.commitOffset(payload);
            this.logger.log(`Successfully processed transfer [${event.transferId}] — offset committed`);
        }
        catch (error) {
            const errMsg = error instanceof Error ? error.message : 'Unknown error';
            this.logger.error(`Failed to process message: topic="${topic}" key=${key} offset=${message.offset} — ${errMsg}`);
            try {
                const dlqTopic = 'transfer.initiated.dlq';
                await this.publishToDlq(dlqTopic, key, rawValue, errMsg);
                this.logger.warn(`Message sent to DLQ "${dlqTopic}": key=${key}`);
            }
            catch (dlqError) {
                this.logger.error(`Failed to send message to DLQ: key=${key}`, dlqError);
            }
            await this.commitOffset(payload);
        }
    }
    async publishToDlq(dlqTopic, key, originalValue, errorReason) {
        const { Kafka: KafkaDlq } = await Promise.resolve().then(() => require('kafkajs'));
        const dlqKafka = new KafkaDlq({
            clientId: 'banking-dlq-producer',
            brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
        });
        const dlqProducer = dlqKafka.producer();
        try {
            await dlqProducer.connect();
            await dlqProducer.send({
                topic: dlqTopic,
                messages: [
                    {
                        key,
                        value: originalValue,
                        headers: {
                            'dlq-reason': errorReason,
                            'dlq-timestamp': String(Date.now()),
                        },
                    },
                ],
            });
        }
        finally {
            await dlqProducer.disconnect();
        }
    }
    async commitOffset(payload) {
        const { topic, partition, message } = payload;
        await this.consumer.commitOffsets([
            {
                topic,
                partition,
                offset: String(Number(message.offset) + 1),
            },
        ]);
    }
};
exports.KafkaConsumerAdapter = KafkaConsumerAdapter;
exports.KafkaConsumerAdapter = KafkaConsumerAdapter = KafkaConsumerAdapter_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [process_transfer_use_case_1.ProcessTransferUseCase])
], KafkaConsumerAdapter);
//# sourceMappingURL=kafka-consumer.adapter.js.map