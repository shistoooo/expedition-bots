export interface BrainInput {
    agentId: string;
    userId: string;
    content: string;
    sourceChannel: 'discord_dm' | 'discord_channel';
    sourceChannelId?: string;
    senderId: string;
    senderName: string;
    senderType?: 'user' | 'agent' | 'participant' | 'system';
    conversationId?: string;
    missionId?: string;
}
export interface BrainResponse {
    responseText: string;
    conversationId?: string;
    missionId?: string | null;
    proposedActions?: Array<{
        actionType: string;
        targetId?: string;
        content: string;
        requiresApproval: boolean;
    }>;
}
export declare function callBrain(input: BrainInput): Promise<BrainResponse>;
