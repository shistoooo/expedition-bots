import { BotConfig } from './config';
export declare class ExpeditionBot {
    private client;
    private config;
    private token;
    private targetChannelId;
    private guild;
    constructor(config: BotConfig);
    private postInChannel;
    private replyTo;
    private handleTask;
    start(): Promise<void>;
}
