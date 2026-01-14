const ASSISTANT_URL =
  'https://chatgpt.com/g/g-68f9371179548191a018ea1e1ff99727-finsight-assistant';

export function AssistantChat() {
  const handleClick = () => {
    if (typeof window !== 'undefined') {
      window.open(ASSISTANT_URL, '_blank', 'noopener,noreferrer');
    }
  };

  return (
    <button
      type="button"
      onClick={handleClick}
      className="fixed bottom-6 right-6 z-[1000] rounded-full bg-blue-600 px-5 py-3 text-sm font-semibold text-white shadow-2xl transition hover:bg-blue-500"
    >
      Ask FinSight
    </button>
  );
}
