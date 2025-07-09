import { LightningElement, api } from "lwc";
export default class SampleComp01 extends LightningElement {
	@api welcome;
	@api getState;
	@api setState;
	@api refresh;
	@api
	stateChangedCallback(prevState, newState) {
		console.log('State changed:', prevState, '=>', newState);
	}

	handleButtonClick() {
		if (this.setState) {
			const newState = { updated: true, time: Date.now() };
			this.setState(newState);
		}
	}
}