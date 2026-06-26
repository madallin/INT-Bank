"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.KafkaModule = void 0;
const common_1 = require("@nestjs/common");
const kafka_producer_adapter_1 = require("./kafka-producer.adapter");
const kafka_consumer_adapter_1 = require("./kafka-consumer.adapter");
const event_publisher_interface_1 = require("../../../../../core/ports/out/event-publisher.interface");
const application_module_1 = require("../../../../../application/application.module");
let KafkaModule = class KafkaModule {
};
exports.KafkaModule = KafkaModule;
exports.KafkaModule = KafkaModule = __decorate([
    (0, common_1.Module)({
        imports: [application_module_1.ApplicationModule],
        providers: [
            {
                provide: event_publisher_interface_1.EventPublisher,
                useClass: kafka_producer_adapter_1.KafkaProducerAdapter,
            },
            kafka_producer_adapter_1.KafkaProducerAdapter,
            kafka_consumer_adapter_1.KafkaConsumerAdapter,
        ],
        exports: [event_publisher_interface_1.EventPublisher, kafka_producer_adapter_1.KafkaProducerAdapter],
    })
], KafkaModule);
//# sourceMappingURL=kafka.module.js.map