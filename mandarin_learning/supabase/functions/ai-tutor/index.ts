import { handleAiTutor } from "../_shared/ai_tutor_handler.ts";

Deno.serve((request) => handleAiTutor(request));
