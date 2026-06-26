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
var KafkaProducerAdapter_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.KafkaProducerAdapter = void 0;
const common_1 = require("@nestjs/common");
const kafkajs_1 = require("kafkajs");
const event_publisher_interface_1 = require("../../../../../core/ports/out/event-publisher.interface");
let KafkaProducerAdapter = KafkaProducerAdapter_1 = class KafkaProducerAdapter extends event_publisher_interface_1.EventPublisher {
    constructor() {
        super();
        this.logger = new common_1.Logger(KafkaProducerAdapter_1.name);
        const brokers = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
        this.kafka = new kafkajs_1.Kafka({
            clientId: 'banking-nestjs-producer',
            brokers,
            logLevel: kafkajs_1.logLevel.INFO,
            retry: {
                initialRetryTime: 300,
                retries: 10,
                maxRetryTime: 30000,
            },
        });
        this.producer = this.kafka.producer({
            allowAutoTopicCreation: true,
            transactionTimeout: 30000,
        });
    }
    async onModuleInit() {
        try {
            await this.producer.connect();
            this.logger.log('Kafka producer connected');
        }
        catch (error) {
            this.logger.error('Failed to connect Kafka producer', error);
        }
    }
    async onModuleDestroy() {
        try {
            await this.producer.disconnect();
            this.logger.log('Kafka producer disconnected');
        }
        catch (error) {
            this.logger.warn('Error disconnecting Kafka producer', error);
        }
    }
    async publish(topic, key, event) {
        try {
            await this.producer.send({
                topic,
                messages: [
                    {
                        key,
                        value: JSON.stringify(event),
                        headers: {
                            'content-type': 'application/json',
                            'event-type': topic,
                            'source': 'banking-nestjs',
                            'timestamp': String(Date.now()),
                        },
                    },
                ],
                acks: -1,
            });
            this.logger.debug(`Published event to topic "${topic}": key=${key}`);
        }
        catch (error) {
            this.logger.error(`Failed to publish event to topic "${topic}": key=${key}`, error);
            throw error;
        }
    }
};
exports.KafkaProducerAdapter = KafkaProducerAdapter;
exports.KafkaProducerAdapter = KafkaProducerAdapter = KafkaProducerAdapter_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [])
], KafkaProducerAdapter);
//# sourceMappingURL=kafka-producer.adapter.js.map