--// Lib Decleration
local types					= {}

--// Lib Types
export type customTask		=
{
	id						: string, --?
	operationType			: number,
	callbackOrActor			: (number, ...any) -> (...any?) | string,
	interval				: number,
}

return types